require 'spec_helper'
require 'actions/droplet_create'

module VCAP::CloudController
  RSpec.describe DropletCreate do
    subject(:droplet_create) { DropletCreate.new }
    let(:app) { AppModel.make }
    let(:package) { PackageModel.make app: app }
    let(:build) { BuildModel.make app: app, package: package }

    describe '#create_docker_droplet' do
      before do
        package.update(docker_username: 'docker-username', docker_password: 'example-docker-password')
      end

      it 'creates a droplet for build' do
        expect {
          droplet_create.create_docker_droplet(build)
        }.to change { DropletModel.count }.by(1)

        droplet = DropletModel.last

        expect(droplet.state).to eq(DropletModel::STAGING_STATE)
        expect(droplet.app).to eq(app)
        expect(droplet.package_guid).to eq(package.guid)
        expect(droplet.build).to eq(build)

        expect(droplet.docker_receipt_username).to eq('docker-username')
        expect(droplet.docker_receipt_password).to eq('example-docker-password')

        expect(droplet.buildpack_lifecycle_data).to be_nil
      end
    end

    describe '#create_buildpack_droplet' do
      let!(:buildpack_lifecycle_data) { BuildpackLifecycleDataModel.make(build: build) }

      it 'sets it on the droplet' do
        expect {
          droplet_create.create_buildpack_droplet(build)
        }.to change { DropletModel.count }.by(1)

        droplet = DropletModel.last

        expect(droplet.state).to eq(DropletModel::STAGING_STATE)
        expect(droplet.app).to eq(app)
        expect(droplet.package).to eq(package)
        expect(droplet.build).to eq(build)

        buildpack_lifecycle_data.reload
        expect(buildpack_lifecycle_data.droplet).to eq(droplet)
      end
    end
  end
end
