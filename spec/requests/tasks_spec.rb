ENV['RACK_ENV'] = 'test'
require 'rack/test'
require 'spec_helper'

describe 'Tasks' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

  describe '#create' do
    let(:space) { VCAP::CloudController::Space.make }
    let!(:org) { space.organization }
    let!(:user) { VCAP::CloudController::User.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let!(:droplet) do
      VCAP::CloudController::DropletModel.make(app_guid: app_model.guid,
                                               state: VCAP::CloudController::DropletModel::STAGED_STATE)
    end

    before do
      app_model.droplet = droplet
      app_model.save
    end

    it 'creates a task for an app with an assigned current droplet' do
      body = {
        name: 'best task ever',
        command: 'be rake && true'
      }
      post "/v3/apps/#{app_model.guid}/tasks", body, admin_headers

      expect(last_response.status).to eq(202)
      parsed_body = JSON.load(last_response.body)
      expect(parsed_body['name']).to eq('best task ever')
      expect(parsed_body['command']).to eq('be rake && true')
      expect(parsed_body['state']).to eq('RUNNING')
      expect(parsed_body['result']).to eq({ 'message' => nil })

      guid = VCAP::CloudController::TaskModel.last.guid
      expect(parsed_body['links']['self']).to eq({ 'href' => "/v3/tasks/#{guid}" })
      expect(parsed_body['links']['app']).to eq({ 'href' => "/v3/apps/#{app_model.guid}" })
      expect(parsed_body['links']['droplet']).to eq({ 'href' => "/v3/droplets/#{droplet.guid}" })
    end
  end
end
