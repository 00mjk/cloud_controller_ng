require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Users Request' do
  let(:user) { VCAP::CloudController::User.make(guid: 'user1') }
  let(:client) { VCAP::CloudController::User.make(guid: 'client-user') }
  let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }
  let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }
  let(:other_user) { VCAP::CloudController::User.make(guid: other_user_guid) }
  let(:other_user_guid) { 'some-user-guid' }

  let(:organization1) { VCAP::CloudController::Organization.make }
  let(:organization2) { VCAP::CloudController::Organization.make }

  let(:space1) { VCAP::CloudController::Space.make(organization: organization1) }
  let(:space2a) { VCAP::CloudController::Space.make(organization: organization2) }
  let(:space2b) { VCAP::CloudController::Space.make(organization: organization2) }

  let(:space1_user) { VCAP::CloudController::User.make(guid: 'space1-user') }
  let(:space2a_user) { VCAP::CloudController::User.make(guid: 'space2a-user') }
  let(:space2b_user) { VCAP::CloudController::User.make(guid: 'space2b-user') }
  let(:organization1_user) { VCAP::CloudController::User.make(guid: 'organization1-user') }
  let(:organization2_user) { VCAP::CloudController::User.make(guid: 'organization2-user') }

  let(:space_role) { VCAP::CloudController::SpaceAuditor.make(guid: 'space1-role-guid', space: space1, user: space1_user) }
  let(:space2a_role) { VCAP::CloudController::SpaceManager.make(guid: 'space2a-role-guid', space: space2a, user: space2a_user) }
  let(:space2b_role) { VCAP::CloudController::SpaceManager.make(guid: 'space2b-role-guid', space: space2b, user: space2b_user) }
  let(:organization1_role) { VCAP::CloudController::OrganizationAuditor.make(guid: 'organization1-role-guid', space: organization1, user: organization1_user) }
  let(:organization2_role) { VCAP::CloudController::OrganizationBillingManager.make(guid: 'organization2-role-guid', space: organization2, user: organization2_user) }

  before do
    VCAP::CloudController::User.dataset.destroy # this will clean up the seeded test users
    allow(VCAP::CloudController::UaaClient).to receive(:new).and_return(uaa_client)
    allow(uaa_client).to receive(:users_for_ids).with(contain_exactly(other_user_guid, client.guid, user.guid)).and_return(
      {
        user.guid => { 'username' => 'bob-mcjames', 'origin' => 'Okta' },
        other_user.guid => { 'username' => 'lola', 'origin' => 'uaa' },
      }
    )
    allow(uaa_client).to receive(:users_for_ids).with([user.guid]).and_return(
      {
        user.guid => { 'username' => 'bob-mcjames', 'origin' => 'Okta' },
      }
    )
    allow(uaa_client).to receive(:users_for_ids).with([client.guid]).and_return({})
    allow(uaa_client).to receive(:users_for_ids).with([other_user.guid]).and_return(
      {
        other_user.guid => { 'username' => 'lola', 'origin' => 'uaa' },
      }
    )
  end

  describe 'GET /v3/users' do
    let(:current_user_json) do
      {
        guid: user.guid,
        created_at: iso8601,
        updated_at: iso8601,
        username: 'bob-mcjames',
        presentation_name: 'bob-mcjames',
        origin: 'Okta',
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user.guid}) },
        }
      }
    end

    let(:client_json) do
      {
        guid: client.guid,
        created_at: iso8601,
        updated_at: iso8601,
        username: nil,
        presentation_name: client.guid,
        origin: nil,
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{client.guid}) },
        }
      }
    end

    let(:other_user_json) do
      {
        guid: other_user.guid,
        created_at: iso8601,
        updated_at: iso8601,
        username: 'lola',
        presentation_name: 'lola',
        origin: 'uaa',
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{other_user.guid}) },
        }
      }
    end

    context 'without filters' do
      let(:api_call) { lambda { |user_headers| get '/v3/users', nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: [
            current_user_json
          ]
        )
        h['admin'] = {
          code: 200,
          response_objects: [
            other_user_json,
            client_json,
            current_user_json
          ]
        }
        h['admin_read_only'] = {
          code: 200,
          response_objects: [
            other_user_json,
            client_json,
            current_user_json
          ]
        }
        h.freeze
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'with filters' do
      describe 'when filtering by guid' do
        let(:endpoint) { "/v3/users?guids=#{user.guid}" }
        let(:api_call) { lambda { |user_headers| get endpoint, nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_objects: [
              current_user_json
            ]
          )
          h['admin'] = {
            code: 200,
            response_objects: [
              current_user_json
            ]
          }
          h['admin_read_only'] = {
            code: 200,
            response_objects: [
              current_user_json
            ]
          }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      describe 'labels' do
        let!(:user_label) { VCAP::CloudController::UserLabelModel.make(resource_guid: user.guid, key_name: 'animal', value: 'dog') }

        let!(:other_user_label) { VCAP::CloudController::UserLabelModel.make(resource_guid: other_user.guid, key_name: 'animal', value: 'cow') }

        it 'returns a 200 and the filtered routes for "in" label selector' do
          get '/v3/users?label_selector=animal in (dog)', nil, admin_header

          parsed_response = MultiJson.load(last_response.body)

          expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/users?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/users?label_selector=animal+in+%28dog%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
          }

          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(user.guid)
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/users', nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'GET /v3/users/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/users/#{other_user.guid}", nil, user_headers } }

    let(:client_json) do
      {
        guid: other_user.guid,
        created_at: iso8601,
        updated_at: iso8601,
        username: 'lola',
        presentation_name: 'lola',
        origin: 'uaa',
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{other_user.guid}) },
        }
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 404,
        response_objects: []
      )
      h['admin'] = {
        code: 200,
        response_object: client_json
      }
      h['admin_read_only'] = {
        code: 200,
        response_object: client_json
      }
      h.freeze
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    describe 'user visibility' do
      let(:org) { VCAP::CloudController::Organization.make }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }

      ALL_PERMISSIONS.each do |actee_role|
        context "viewing a user with role #{actee_role}" do
          let(:actee_user) { VCAP::CloudController::User.make }
          let(:api_call) { lambda { |user_headers| get "/v3/users/#{actee_user.guid}", nil, user_headers } }
          let(:user_header) { headers_for(user, scopes: %w(cloud_controller.read)) }

          let(:actee_user_json) do
            {
              guid: actee_user.guid,
              created_at: iso8601,
              updated_at: iso8601,
              username: 'merric',
              presentation_name: 'merric',
              origin: 'uaa',
              metadata: {
                labels: {},
                annotations: {}
              },
              links: {
                self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{actee_user.guid}) },
              }
            }
          end

          let(:expected_codes_and_responses) do
            h = Hash.new(code: 404)

            h['admin'] = { code: 200, response_object: actee_user_json }

            h['admin_read_only'] = { code: 200, response_object: actee_user_json }
            h['global_auditor'] = { code: 200, response_object: actee_user_json }

            h['space_developer'] = { code: 200, response_object: actee_user_json }
            h['space_manager'] = { code: 200, response_object: actee_user_json }
            h['space_auditor'] = { code: 200, response_object: actee_user_json }

            if %w[org_manager org_auditor org_billing_manager].include?(actee_role)
              h['org_manager'] = { code: 200, response_object: actee_user_json }
              h['org_auditor'] = { code: 200, response_object: actee_user_json }
              h['org_billing_manager'] = { code: 200, response_object: actee_user_json }

            elsif %w[space_developer space_manager space_auditor].include?(actee_role)
              h['org_auditor'] = { code: 404, response_object: actee_user_json }
              h['org_billing_manager'] = { code: 404, response_object: actee_user_json }
            end

            h.freeze
          end

          before do
            allow(uaa_client).to receive(:users_for_ids).with([actee_user.guid]).and_return(
              {
                actee_user.guid => { 'username' => 'merric', 'origin' => 'uaa' },
              }
            )

            set_current_user_as_role(role: actee_role, org: org, space: space, user: actee_user)
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get "/v3/users/#{user.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    describe 'when the user is logged in' do
      let(:user_header) { headers_for(user, scopes: %w(cloud_controller.read)) }

      before do
        set_current_user_as_role(role: 'space_developer', org: org, space: space1, user: user)
      end

      it 'returns 200 when showing current user' do
        get "/v3/users/#{user.guid}", nil, user_header
        expect(last_response.status).to eq(200)
        expect(parsed_response).to include('guid' => user.guid)
      end

      describe 'when the user is not found' do
        it 'returns 404' do
          get '/v3/users/unknown-user', nil, admin_headers
          expect(last_response.status).to eq(404)
          expect(last_response).to have_error_message('User not found')
        end
      end
    end
  end

  describe 'POST /v3/users' do
    let(:params) do
      {
        guid: other_user_guid,
      }
    end

    describe 'metadata' do
      before do
        allow(uaa_client).to receive(:users_for_ids).and_return({})
      end
      let(:user_json) do
        {
          guid: params[:guid],
          created_at: iso8601,
          updated_at: iso8601,
          username: nil,
          presentation_name: params[:guid],
          origin: nil,
          metadata: {
            labels: {
              'potato': 'yam',
              'style': 'casserole',
            },
            annotations: {
              'potato': 'russet',
              'style': 'french',
            },
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{params[:guid]}) },
          }
        }
      end

      context 'when metadata is valid' do
        it 'returns a 201' do
          post '/v3/users', {
            guid: params[:guid],
            metadata: {
              labels: {
                'potato': 'yam',
                'style': 'casserole',
              },
              annotations: {
                'potato': 'russet',
                'style': 'french',
              }
            }
          }.to_json, admin_header

          expect(parsed_response).to match_json_response(user_json)
          expect(last_response.status).to eq(201)
        end
      end

      context 'when metadata is invalid' do
        it 'returns a 422' do
          post '/v3/users', {
            metadata: {
              labels: { '': 'invalid' },
              annotations: { "#{'a' * 1001}": 'value2' }
            }
          }.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to match(/label [\w\s]+ error/)
          expect(parsed_response['errors'][0]['detail']).to match(/annotation [\w\s]+ error/)
        end
      end
    end

    describe 'when creating a user that does not exist in uaa' do
      before do
        allow(uaa_client).to receive(:users_for_ids).and_return({})
      end

      let(:api_call) { lambda { |user_headers| post '/v3/users', params.to_json, user_headers } }

      let(:user_json) do
        {
          guid: params[:guid],
          created_at: iso8601,
          updated_at: iso8601,
          username: nil,
          presentation_name: params[:guid],
          origin: nil,
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: user_json
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    describe 'when creating a user that exists in uaa' do
      context "it's a UAA user" do
        before do
          allow(uaa_client).to receive(:users_for_ids).and_return({ other_user_guid => { 'username' => 'bob-mcjames', 'origin' => 'Okta' } })
        end

        let(:api_call) { lambda { |user_headers| post '/v3/users', params.to_json, user_headers } }

        let(:user_json) do
          {
            guid: params[:guid],
            created_at: iso8601,
            updated_at: iso8601,
            username: 'bob-mcjames',
            presentation_name: 'bob-mcjames',
            origin: 'Okta',
            metadata: {
              labels: {},
              annotations: {}
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{params[:guid]}) },
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 201,
            response_object: user_json
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
      context "it's a UAA client" do
        let(:params) do
          {
            guid: uaa_client_id,
          }
        end
        let(:uaa_client_id) { 'cc_routing' }

        before do
          allow(uaa_client).to receive(:users_for_ids).and_return({})
          allow(uaa_client).to receive(:get_clients).and_return([{ client_id: uaa_client_id }])
        end

        let(:api_call) { lambda { |user_headers| post '/v3/users', params.to_json, user_headers } }

        let(:user_json) do
          {
            guid: uaa_client_id,
            created_at: iso8601,
            updated_at: iso8601,
            username: nil,
            presentation_name: uaa_client_id,
            origin: nil,
            metadata: {
              labels: {},
              annotations: {}
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{uaa_client_id}) },
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
          h['admin'] = {
            code: 201,
            response_object: user_json
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end
    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/users', params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/users', params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when the params are invalid' do
      let(:headers) { set_user_with_header_as_role(role: 'admin') }

      context 'when provided invalid arguments' do
        let(:params) do
          {
            guid: 555
          }
        end

        it 'returns 422' do
          post '/v3/users', params.to_json, headers

          expect(last_response.status).to eq(422)

          expected_err = [
            'Guid must be a string, Guid must be between 1 and 200 characters',
          ]
          expect(parsed_response['errors'][0]['detail']).to eq expected_err.join(', ')
        end
      end

      context 'with an existing user' do
        let!(:existing_user) { VCAP::CloudController::User.make }

        let(:params) do
          {
            guid: existing_user.guid,
          }
        end

        it 'returns 422' do
          post '/v3/users', params.to_json, headers

          expect(last_response.status).to eq(422)

          expect(parsed_response['errors'][0]['detail']).to eq "User with guid '#{existing_user.guid}' already exists."
        end
      end
    end
  end

  describe 'PATCH /v3/users/:guid' do
    describe 'metadata' do
      let(:params) do
        {
          metadata: {
            labels: {
              'potato': 'yam',
              'style': 'casserole',
            },
            annotations: {
              'potato': 'russet',
              'style': 'french',
            }
          }
        }
      end

      let(:api_call) { lambda { |user_headers| patch "/v3/users/#{other_user.guid}", params.to_json, user_headers } }

      let(:client_json) do
        {
          guid: other_user.guid,
          created_at: iso8601,
          updated_at: iso8601,
          username: 'lola',
          presentation_name: 'lola',
          origin: 'uaa',
          metadata: {
            labels: {
              'potato': 'yam',
              'style': 'casserole',
            },
            annotations: {
              'potato': 'russet',
              'style': 'french',
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{other_user.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 404,
          response_objects: []
        )
        h['admin'] = {
          code: 200,
          response_object: client_json
        }
        h['admin_read_only'] = {
          code: 403,
          response_object: client_json
        }
        h['global_auditor'] = {
          code: 404,
          scopes: %w(cloud_controller.write),
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when metadata is invalid' do
        it 'returns a 422' do
          patch "/v3/users/#{other_user.guid}", {
            metadata: {
              labels: { '': 'invalid' },
              annotations: { "#{'a' * 1001}": 'value2' }
            }
          }.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors'][0]['detail']).to match(/label [\w\s]+ error/)
          expect(parsed_response['errors'][0]['detail']).to match(/annotation [\w\s]+ error/)
        end
      end
    end
  end

  describe 'DELETE /v3/users/:guid' do
    let(:user_to_delete) { VCAP::CloudController::User.make }
    let(:api_call) { lambda { |user_headers| delete "/v3/users/#{user_to_delete.guid}", nil, user_headers } }
    let(:db_check) do
      lambda do
        expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

        execute_all_jobs(expected_successes: 1, expected_failures: 0)
        get "/v3/users/#{user_to_delete.guid}", {}, admin_headers
        expect(last_response.status).to eq(404)
      end
    end

    context 'when the user is a member in the routes org' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)

        h['admin_read_only'] = { code: 403 }
        h['global_auditor'] = { code: 403 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 202 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        delete "/v3/users/#{user_to_delete.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    describe 'when the user is logged in' do
      describe 'when the current non-admin user tries to delete themselves' do
        let(:user_header) { headers_for(user_to_delete, scopes: %w(cloud_controller.write)) }
        before do
          set_current_user_as_role(role: 'space_developer', organization1: org, space1: space1, user: user_to_delete)
        end

        it 'returns 403' do
          delete "/v3/users/#{user_to_delete.guid}", nil, user_header
          expect(last_response.status).to eq(403)
        end
      end

      describe 'when the user is admin_read_only and has cloud_controller.write scope' do
        let(:user_header) { headers_for(user, scopes: %w(cloud_controller.admin_read_only cloud_controller.write)) }

        it 'returns 403' do
          delete "/v3/users/#{user_to_delete.guid}", nil, user_header
          expect(last_response.status).to eq(403)
        end
      end

      describe 'when the user is not found' do
        let(:user_header) { headers_for(user_to_delete, scopes: %w(cloud_controller.write)) }

        before do
          set_current_user_as_role(role: 'space_developer', organization1: org, space1: space1, user: user_to_delete)
        end

        it 'returns 404' do
          delete '/v3/users/unknown-user', nil, user_header
          expect(last_response.status).to eq(404)
          expect(last_response).to have_error_message('User not found')
        end
      end
    end
  end
end
