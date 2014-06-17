require "spec_helper"

module VCAP::CloudController
  describe AppSecurityGroupsController do
    let(:group) { AppSecurityGroup.make }

    it_behaves_like "an admin only endpoint", path: "/v2/app_security_groups"
    include_examples "enumerating objects", path: "/v2/app_security_groups", model: AppSecurityGroup
    include_examples "reading a valid object", path: "/v2/app_security_groups", model: AppSecurityGroup, basic_attributes: %w(name rules)
    include_examples "querying objects", path: "/v2/app_security_groups", model: AppSecurityGroup, queryable_attributes: %w(name)

    describe "errors" do
      it "returns AppSecurityGroupInvalid" do
        post '/v2/app_security_groups', '{"name":"one\ntwo"}', json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/app security group is invalid/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupInvalid/)
      end
    end
  end
end
