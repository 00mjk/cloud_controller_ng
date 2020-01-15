require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'space_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
    let!(:org) { VCAP::CloudController::Organization.make(guid: 'organization-guid') }
    let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'space-quota-guid', organization: org) }
    let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org, space_quota_definition: space_quota) }
    let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

    describe 'POST /v3/space_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/space_quotas', params.to_json, user_headers } }

      let(:params) do
        {
          'name': 'quota1',
          'relationships': {
            'organization': {
              'data': { 'guid': org.guid }
            }
          }
        }
      end

      let(:space_quota_json) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
          relationships: {
            organization: {
              data: { 'guid': org.guid },
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{params[:guid]}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: space_quota_json
        }
        h['org_manager'] = {
          code: 201,
          response_object: space_quota_json
        }
        h.freeze
      end

      context 'using the default params' do
        it 'creates a space_quota' do
          expect {
            api_call.call(admin_header)
          }.to change {
            SpaceQuotaDefinition.count
          }.by 1
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'using provided params' do
        let(:params) do
          {
            'name': 'my-space-quota',
            'relationships': {
              'organization': {
                'data': { 'guid': org.guid }
              }
            }
          }
        end

        let(:expected_response) do
          {
            'guid': UUID_REGEX,
            'created_at': iso8601,
            'updated_at': iso8601,
            'name': 'my-space-quota',
            'relationships': {
              'organization': {
                'data': {
                  'guid': org.guid
                }
              }
            },
            'links': {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{params[:guid]}) },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            }
          }
        end

        it 'responds with the expected code and response' do
          api_call.call(admin_header)
          expect(last_response).to have_status_code(201)
          expect(parsed_response).to match_json_response(expected_response)
        end
      end

      context 'when the org guid is invalid' do
        let(:params) do
          {
            name: 'quota-with-bad-org',
            relationships: {
              organization: {
                data: { guid: 'not-real' }
              }
            }
          }
        end

        it 'returns 422' do
          post '/v3/space_quotas', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message('Organization with guid \'not-real\' does not exist, or you do not have access to it.')
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post '/v3/space_quotas', params.to_json, base_json_headers
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
            post '/v3/space_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message('Name must be a string')
          end
        end

        context 'with a pre-existing name' do
          let(:params) do
            {
              name: 'double-trouble',
              relationships: {
                organization: {
                  data: { guid: org.guid }
                }
              }
            }
          end

          it 'returns 422' do
            post '/v3/space_quotas', params.to_json, headers
            post '/v3/space_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message("Space Quota 'double-trouble' already exists.")
          end
        end
      end
    end
  end
end
