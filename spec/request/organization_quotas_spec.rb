require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'organization_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
    let(:organization_quota) { VCAP::CloudController::QuotaDefinition.make }
    let!(:org) { VCAP::CloudController::Organization.make(guid: 'organization-guid', quota_definition: organization_quota) }
    let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org) }
    let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

    describe 'POST /v3/organization_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/organization_quotas', params.to_json, user_headers } }

      let(:params) do
        {
          'name': 'quota1',
          'relationships': {
            'organizations': {
              'data': [
                { 'guid': org.guid },
              ]
            }
          }
        }
      end

      let(:organization_quota_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          apps: {
            total_memory_in_mb: nil,
            per_process_memory_in_mb: nil,
            total_instances: nil,
            per_app_tasks: nil
          },
          services: {
            paid_services_allowed: true,
            total_service_instances: nil,
            total_service_keys: nil
          },
          routes: {
            total_routes: nil,
            total_reserved_ports: nil,
          },
          domains: {
            total_domains: nil,
          },
          relationships: {
            organizations: {
              data: [{ 'guid': 'organization-guid' }],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: organization_quota_json
        }
        h.freeze
      end

      context 'using the default params' do
        it 'creates a organization_quota' do
          expect {
            api_call.call(admin_header)
          }.to change {
            QuotaDefinition.count
          }.by 1
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'using provided params' do
        let(:params) do
          {
            'name': 'org1',
            'apps': {
              'total_memory_in_mb': 5120,
              'per_process_memory_in_mb': 1024,
              'total_instances': 10,
              'per_app_tasks': 5
            },
            "services": {
              "paid_services_allowed": false,
              "total_service_instances": 10,
              "total_service_keys": 20
            },
            "routes": {
              "total_routes": 8,
              "total_reserved_ports": 4
            },
            'domains': {
              'total_domains': 7,
            },
          }
        end

        let(:expected_response) do
          {
            'guid': UUID_REGEX,
            'created_at': iso8601,
            'updated_at': iso8601,
            'name': 'org1',
            'apps': {
              'total_memory_in_mb': 5120,
              'per_process_memory_in_mb': 1024,
              'total_instances': 10,
              'per_app_tasks': 5
            },
            "services": {
              "paid_services_allowed": false,
              "total_service_instances": 10,
              "total_service_keys": 20
            },
            "routes": {
              "total_routes": 8,
              "total_reserved_ports": 4
            },
            'domains': {
              'total_domains': 7,
            },
            'relationships': {
              'organizations': {
                'data': [],
              },
            },
            'links': {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
            }
          }
        end

        it 'responds with the expected code and response' do
          api_call.call(admin_header)
          expect(last_response).to have_status_code(201)
          expect(parsed_response).to match_json_response(expected_response)
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post '/v3/organization_quotas', params.to_json, base_json_headers
          expect(last_response).to have_status_code(401)
        end
      end

      context 'when the params are invalid' do
        let(:headers) { set_user_with_header_as_role(role: 'admin') }

        context 'when provided invalid arguments' do
          let(:params) do
            {
              name: 555,
            }
          end

          it 'returns 422' do
            post '/v3/organization_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message('Name must be a string')
          end
        end

        context 'with a pre-existing name' do
          let(:params) do
            {
              name: 'double-trouble',
            }
          end

          it 'returns 422' do
            post '/v3/organization_quotas', params.to_json, headers
            post '/v3/organization_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message("Organization Quota 'double-trouble' already exists.")
          end
        end
      end
    end

    describe 'GET /v3/organization_quotas/:guid' do
      let(:api_call) { lambda { |user_headers| get "/v3/organization_quotas/#{organization_quota.guid}", nil, user_headers } }

      context 'when getting an organization_quota' do
        let!(:other_org) { VCAP::CloudController::Organization.make(guid: 'other-organization-guid', quota_definition: organization_quota) }
        let(:other_org_response) { { 'guid': 'other-organization-guid' } }
        let(:org_response) { { 'guid': 'organization-guid' } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 200, response_object: generate_response_org_quota([org_response]))
          h['admin'] = { code: 200, response_object: generate_response_org_quota([org_response, other_org_response]) }
          h['admin_read_only'] = { code: 200, response_object: generate_response_org_quota([org_response, other_org_response]) }
          h['global_auditor'] = { code: 200, response_object: generate_response_org_quota([org_response, other_org_response]) }
          h['no_role'] = { code: 200, response_object: generate_response_org_quota([]) }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the organization_quota had no associated organizations' do
        let(:unused_organization_quota) { VCAP::CloudController::QuotaDefinition.make }

        it 'returns a quota with an empty array of org guids' do
          get "/v3/organization_quotas/#{unused_organization_quota.guid}", nil, admin_header

          expect(last_response).to have_status_code(200)
          expect(parsed_response['relationships']['organizations']['data']).to eq([])
        end
      end

      context 'when the organization_quota does not exist' do
        it 'returns a 404 with a helpful message' do
          get '/v3/organization_quotas/not-exist', nil, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Organization quota not found')
        end
      end

      context 'when not logged in' do
        it 'returns a 401 with a helpful message' do
          get '/v3/organization_quotas/not-exist', nil, {}
          expect(last_response).to have_status_code(401)
          expect(last_response).to have_error_message('Authentication error')
        end
      end
    end
  end
end

def generate_response_org_quota(list_of_orgs)
  {
    guid: organization_quota.guid,
    created_at: iso8601,
    updated_at: iso8601,
    name: organization_quota.name,
    apps: {
      total_memory_in_mb: 20480,
      per_process_memory_in_mb: nil,
      total_instances: nil,
      per_app_tasks: nil
    },
    services: {
      paid_services_allowed: true,
      total_service_instances: 60,
      total_service_keys: nil,
    },
    routes: {
      total_routes: 1000,
      total_reserved_ports: 5
    },
    domains: {
      total_domains: nil
    },
    relationships: {
      organizations: {
        data: list_of_orgs
      }
    },
    links: {
      self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{organization_quota.guid}) },
    }
  }
end
