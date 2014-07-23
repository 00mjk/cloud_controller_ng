require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Quota Definitions", type: :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let(:guid) { VCAP::CloudController::QuotaDefinition.make.guid }

  authenticated_request

  shared_context "guid_parameter" do
    parameter :guid, "The guid of the Quota Definition"
  end

  shared_context "updatable_fields" do
    field :name, "The name for the Quota Definition.", required: true, example_values: ["gold_quota"]
    field :non_basic_services_allowed, "If an organization can have non basic services", required: true, valid_values: [true, false]
    field :total_services, "How many services an organization can have.", required: true, example_values: [5, 201]
    field :total_routes, "How many routes an organization can have.", required: true, example_values: [10, 23]
    field :memory_limit, "How much memory in megabyte an organization can have.", required: true, example_values: [5_120, 10_024]
    field :instance_memory_limit, "The maximum amount of memory in megabyte an application instance can have. (-1 represents an unlimited amount)", default: -1, example_values: [-1, 10_024]
    field :trial_db_allowed, "If an organization can have a trial db.", required: false, deprecated: true
  end

  standard_model_list(:quota_definition, VCAP::CloudController::QuotaDefinitionsController)
  standard_model_get(:quota_definition)
  standard_model_delete(:quota_definition)

  post "/v2/quota_definitions" do
    include_context "updatable_fields"
    example "Creating a Quota Definition" do
      client.post "/v2/quota_definitions", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :quota_definition
    end
  end

  put "/v2/quota_definitions/:guid" do
    include_context "guid_parameter"
    include_context "updatable_fields"
    example "Updating a Quota Definition" do
      client.put "/v2/quota_definitions/#{guid}", fields_json, headers
      expect(status).to eq(201)

      standard_entity_response parsed_response, :quota_definition
    end
  end
end
