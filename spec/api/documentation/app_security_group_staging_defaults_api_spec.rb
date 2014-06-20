require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "App Security Group Staging Defaults (experimental)", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:app_sec_group) { VCAP::CloudController::AppSecurityGroup.make }
  let!(:staging_default_app_sec_group) { VCAP::CloudController::AppSecurityGroup.make(staging_default: true) }

  authenticated_request

  post "/v2/config/staging_security_groups/:guid" do
    example "Set an App Security Group as a default for staging" do
      client.post "/v2/config/staging_security_groups/#{app_sec_group.guid}", {}, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :app_security_group
    end
  end

  delete "/v2/config/staging_security_groups/:guid" do
    example "Removing an App Security Group as a default for staging" do
      client.delete "/v2/config/staging_security_groups/#{staging_default_app_sec_group.guid}", {}, headers
      status.should == 204
    end
  end

  get "/v2/config/staging_security_groups" do
    example "Return the App Security Groups used for staging" do
      client.get "/v2/config/staging_security_groups", {}, headers
      status.should == 200
      standard_list_response parsed_response, :app_security_group
    end
  end
end
