require 'spec_helper'

RSpec.describe 'ServiceInstances' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v2/service_instances/:service_instance_guid' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(active: false) }

    before do
      service_instance.dashboard_url   = 'someurl.com'
      service_instance.service_plan_id = service_plan.id
      service_instance.save
    end

    context 'with a managed service instance' do
      context 'admin' do
        before do
          set_current_user_as_admin
        end

        it 'lists all service_instances' do
          get "v2/service_instances/#{service_instance.guid}", nil, admin_headers

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
              'entity'   => {
                'name'                 => service_instance.name,
                'credentials'          => service_instance.credentials,
                'service_guid'         => service_instance.service.guid,
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_url'          => "/v2/services/#{service_instance.service.guid}",
                'service_plan_url'     => "/v2/service_plans/#{service_plan.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'      => "/v2/service_instances/#{service_instance.guid}/shared_from"
              }
            }
          )
        end
      end

      context 'space developer' do
        let(:user) { make_developer_for_space(space) }

        before do
          set_current_user(user)
        end

        it 'returns service_plan_guid in the response' do
          get "v2/service_instances/#{service_instance.guid}", nil, headers_for(user)

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
              'entity'   => {
                'name'                 => service_instance.name,
                'credentials'          => service_instance.credentials,
                'service_guid'         => service_instance.service.guid,
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_url'          => "/v2/services/#{service_instance.service.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'      => "/v2/service_instances/#{service_instance.guid}/shared_from"
              }
            }
          )
        end
      end

      context 'space manager' do
        let(:user) { make_manager_for_space(space) }

        before do
          set_current_user(user)
        end
        it 'returns the service_plan_guid in the response' do
          get "v2/service_instances/#{service_instance.guid}", nil, headers_for(user)

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'metadata' => {
                'guid'       => service_instance.guid,
                'url'        => "/v2/service_instances/#{service_instance.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601 },
              'entity'   => {
                'name'                 => service_instance.name,
                'credentials'          => service_instance.credentials,
                'service_guid'         => service_instance.service.guid,
                'service_plan_guid'    => service_plan.guid,
                'space_guid'           => service_instance.space_guid,
                'gateway_data'         => service_instance.gateway_data,
                'dashboard_url'        => service_instance.dashboard_url,
                'type'                 => service_instance.type,
                'last_operation'       => service_instance.last_operation,
                'tags'                 => service_instance.tags,
                'space_url'            => "/v2/spaces/#{space.guid}",
                'service_url'          => "/v2/services/#{service_instance.service.guid}",
                'service_bindings_url' => "/v2/service_instances/#{service_instance.guid}/service_bindings",
                'service_keys_url'     => "/v2/service_instances/#{service_instance.guid}/service_keys",
                'routes_url'           => "/v2/service_instances/#{service_instance.guid}/routes",
                'shared_from_url'      => "/v2/service_instances/#{service_instance.guid}/shared_from"
              }
            }
          )
        end
      end
    end
  end

  describe 'GET /v2/service_instances/:service_instance_guid/shared_from' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }

    before do
      service_instance.add_shared_space(VCAP::CloudController::Space.make)
    end

    it 'returns data about the source space and org' do
      get "v2/service_instances/#{service_instance.guid}/shared_from", nil, admin_headers

      expect(last_response.status).to eq(200), last_response.body

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
        'space_name' => space.name,
        'organization_name' => space.organization.name
      })
    end

    context 'when the user is a member of the space where a service instance has been shared to' do
      let(:other_space) { VCAP::CloudController::Space.make }
      let(:other_user) { make_developer_for_space(other_space) }
      let(:req_body) do
        {
          data: [
            { guid: other_space.guid }
          ]
        }.to_json
      end

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)

        other_space.organization.add_user(user)
        other_space.add_developer(user)

        post "v3/service_instances/#{service_instance.guid}/relationships/shared_spaces", req_body, headers_for(user)
        expect(last_response.status).to eq(200)
      end

      it 'returns data about the source space and org' do
        get "v2/service_instances/#{service_instance.guid}/shared_from", nil, headers_for(other_user)

        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like({
          'space_name' => space.name,
          'organization_name' => space.organization.name
        })
      end
    end
  end
end
