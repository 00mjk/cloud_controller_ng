#!/usr/bin/env bash

set -eu

: "${BOSH_ENVIRONMENT:?}"
: "${BOSH_CLIENT:?}"
: "${BOSH_CLIENT_SECRET:?}"
: "${BOSH_LITE_CIDR:="10.244.0.0/16"}"
: "${BOSH_LITE_IP:="192.168.50.6"}"
: "${BOSH_DEPLOYMENT:="cf"}"
: "${BOSH_API_INSTANCE:="api/0"}"

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cc_dir="$( cd "${script_dir}/.." && pwd )"
tmp_dir="${cc_dir}/tmp"

green='\033[32m'
nc='\033[0m'

enable_direct_container_access() {
  echo "Adding route entries to enable direct container access..."

  if [ "$(uname)" = "Darwin" ]; then
    sudo route delete -net "${BOSH_LITE_CIDR}" "${BOSH_LITE_IP}" > /dev/null
    sudo route add    -net "${BOSH_LITE_CIDR}" "${BOSH_LITE_IP}" > /dev/null
  elif [ "$(uname)" = "Linux" ]; then
    if type route > /dev/null 2>&1; then
      sudo route add -net "${BOSH_LITE_CIDR}" gw "${BOSH_LITE_IP}" > /dev/null
    elif type ip > /dev/null 2>&1; then
      sudo ip route add "${BOSH_LITE_CIDR}" via "${BOSH_LITE_IP}" > /dev/null
    else
      echo "ERROR adding route"
      exit 1
    fi
  fi
}

add_internal_hostnames_to_etc_hosts() {
  echo "Adding internal hostnames to /etc/hosts..."

  # for each DNS name in list, run dig on the remote VM to print "$IP $HOSTNAME" or "UNKNOWN $HOSTNAME" if the DNS record can't be resolved
  internal_hostnames="auctioneer.service.cf.internal \
bbs.service.cf.internal \
bits-service.service.cf.internal \
blobstore.service.cf.internal \
cc-uploader.service.cf.internal \
cell.service.cf.internal \
cloud-controller-ng.service.cf.internal \
loggregator-trafficcontroller.service.cf.internal \
sql-db.service.cf.internal \
uaa.service.cf.internal"
  ip_to_dns="$(bosh ssh "${BOSH_API_INSTANCE}" -c "for addr in ${internal_hostnames}; do ip=\"\$(dig +short \${addr})\" && echo \"\${ip:-\"UNKNOWN\"} \${addr}\"; done"  -r --column=Stdout | cat)"

  while read -r line; do
    if [[ -z "${line}" || "${line}" == UNKNOWN* ]]; then
      continue
    fi

    ip=$(cut -d' ' -f1 <<< "${line}")
    hostname=$(cut -d' ' -f2 <<< "${line}")

    if grep -q "${hostname}" /etc/hosts; then
      sudo sed -i.bak "s/.*${hostname}$/${ip} ${hostname}/g" /etc/hosts
    else
      echo "${ip} ${hostname}" | sudo tee -a /etc/hosts > /dev/null
    fi
  done <<< "${ip_to_dns}"
}

download_cc_config_dir() {
  echo "Downloading CC config dir from ${BOSH_API_INSTANCE}..."

  bosh scp -r \
    "${BOSH_API_INSTANCE}:/var/vcap/jobs/cloud_controller_ng/config/*" \
    "$1" > /dev/null
}

rewrite_config_paths() {
  echo "Rewriting paths in local config..."

  config_dir="$1"
  config_file="${config_dir}cloud_controller_ng.yml"
  sed -i.bak "s~/var/vcap/jobs/cloud_controller_ng/config/~${config_dir}~g" "${config_file}"
  sed -i.bak "s~/var/vcap/sys/run/cloud_controller_ng/~${config_dir}~g" "${config_file}"
  sed -i.bak "s~/var/vcap/data/~${config_dir}~g" "${config_file}"
  sed -i.bak "s~/var/vcap/sys/log/cloud_controller_ng/~${config_dir}~g" "${config_file}"
  sed -i.bak "s~/var/vcap/sys/log/cloud_controller_ng/~${config_dir}~g" "${config_file}"
  sed -i.bak "s~use_nginx: true~use_nginx: false~g" "${config_file}"
  rm -rf "${config_file}.bak"
}

redirect_traffic_to_local_cc() {
  echo "Redirecting traffic from bosh-lite to local process..."

  bosh ssh "${BOSH_API_INSTANCE}" -c "\
    sudo sed -i -- 's#unix:/var/vcap/sys/run/cloud_controller_ng/cloud_controller\.sock#192\.168\.50\.1:9022#g' '/var/vcap/jobs/cloud_controller_ng/config/nginx.conf' && \
    sudo /var/vcap/bosh/bin/monit restart nginx_cc" > /dev/null
}

print_directions() {
  echo -e "\n${green}## Instructions ##${nc}"
  echo -e "The CC API process inside your bosh-lite will now route traffic to port 9022 on your workstation."
  echo -e "\n${green}Option 1: Debug with RubyMine${nc}"
  echo -e "- RubyMine > Run > Edit Configurations... > + > Ruby"
  echo -e "  - Name: 'local_cc'"
  echo -e "  - Ruby script: '${cc_dir}/bin/cloud_controller'"
  echo -e "  - Script arguments: '-c $1cloud_controller_ng.yml'"
  echo -e "  - Hit 'OK'"
  echo -e "- Add breakpoints in code"
  echo -e "- Run > Debug local_cc"
  echo -e "\n${green}Option 2: Debug with pry${nc}"
  echo -e "- Add 'binding.pry' calls in code"
  echo -e "- Run '${cc_dir}/scripts/run-local-cc.sh'"
  echo -e "\n${green}Tail CC logs${nc}"
  echo -e "Run 'tail -f ${cc_dir}/tmp/local-cc/cloud_controller_ng.log'"
  echo -e "\n${green}Restore bosh-lite when finished testing${nc}"
  echo -e "- Run '${cc_dir}/scripts/restore-bosh-lite-cc.sh'"
}

main() {
  enable_direct_container_access
  add_internal_hostnames_to_etc_hosts

  cc_config_dir="${tmp_dir}/local-cc/"
  rm -rf "${cc_config_dir}" && mkdir -p "${cc_config_dir}"
  download_cc_config_dir "${cc_config_dir}"
  rewrite_config_paths "${cc_config_dir}"
  redirect_traffic_to_local_cc
  echo "Done"

  print_directions "${cc_config_dir}"
}

main
