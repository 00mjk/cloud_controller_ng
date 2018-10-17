require 'spec_helper'
require 'cloud_controller/copilot/adapter'
require 'cloud_controller/copilot/sync'

module VCAP::CloudController
  RSpec.describe Copilot::Sync do
    describe '#sync' do
      before do
        allow(Copilot::Adapter).to receive(:bulk_sync)
      end

      context 'syncing' do
        let(:domain) { SharedDomain.make(name: 'example.org') }
        let(:route) { Route.make(domain: domain, host: 'some-host', path: '/some/path') }
        let(:app) { VCAP::CloudController::AppModel.make }
        let!(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'web') }
        let!(:web_process_model) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app) }
        let!(:worker_process_model) { VCAP::CloudController::ProcessModel.make(type: 'worker', app: app) }

        before do
          allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model).and_return('some-diego-process-guid')
        end

        it 'sends routes, route_mappings and CDPAs over to the adapter' do
          Copilot::Sync.sync

          expect(Copilot::Adapter).to have_received(:bulk_sync).with(
            {
              routes: [{
                guid: route.guid,
                host: route.fqdn,
                path: route.path
              }],
              route_mappings: [{
                capi_process_guid: web_process_model.guid,
                route_guid: route_mapping.route_guid,
                route_weight: route_mapping.weight
              }],
              capi_diego_process_associations: [{
                capi_process_guid: web_process_model.guid,
                diego_process_guids: ['some-diego-process-guid']
              }]
            }
          )
        end

        context 'race conditions' do
          context "when a route mapping's process has been deleted" do
            let!(:bad_route_mapping) { RouteMappingModel.make(process: nil, route: route) }

            it 'does not sync that route mapping' do
              Copilot::Sync.sync

              expect(Copilot::Adapter).to have_received(:bulk_sync).with(
                {
                  routes: [{
                    guid: route.guid,
                    host: route.fqdn,
                    path: route.path
                  }],
                  route_mappings: [{
                    capi_process_guid: web_process_model.guid,
                    route_guid: route_mapping.route_guid,
                    route_weight: route_mapping.weight
                  }],
                  capi_diego_process_associations: [{
                    capi_process_guid: web_process_model.guid,
                    diego_process_guids: ['some-diego-process-guid']
                  }]
                }
              )
            end
          end
        end
      end

      context 'batching' do
        before do
          stub_const('VCAP::CloudController::Copilot::Sync::BATCH_SIZE', 1)
          allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model_1).and_return('some-diego-process-guid-1')
          allow(Diego::ProcessGuid).to receive(:from_process).with(web_process_model_2).and_return('some-diego-process-guid-2')
        end

        let(:domain) { SharedDomain.make(name: 'example.org') }
        let(:route_1) { Route.make(domain: domain, host: 'some-host', path: '/some/path') }
        let(:route_2) { Route.make(domain: domain, host: 'some-other-host', path: '/some/other/path') }
        let(:app_1) { VCAP::CloudController::AppModel.make }
        let(:app_2) { VCAP::CloudController::AppModel.make }
        let!(:route_mapping_1) { RouteMappingModel.make(route: route_1, app: app_1, process_type: 'web') }
        let!(:route_mapping_2) { RouteMappingModel.make(route: route_2, app: app_2, process_type: 'web') }
        let!(:web_process_model_1) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app_1) }
        let!(:web_process_model_2) { VCAP::CloudController::ProcessModel.make(type: 'web', app: app_2) }

        it 'syncs all of the resources in one go after querying the DB in batches' do
          Copilot::Sync.sync

          expect(Copilot::Adapter).to have_received(:bulk_sync) do |args|
            expect(args[:routes]).to match_array([
              { guid: route_1.guid, host: route_1.fqdn, path: route_1.path },
              { guid: route_2.guid, host: route_2.fqdn, path: route_2.path }
            ])
            expect(args[:route_mappings]).to match_array([
              {
                capi_process_guid: web_process_model_1.guid,
                route_guid: route_mapping_1.route_guid,
                route_weight: route_mapping_1.weight
              },
              {
                capi_process_guid: web_process_model_2.guid,
                route_guid: route_mapping_2.route_guid,
                route_weight: route_mapping_2.weight
              }
            ])
            expect(args[:capi_diego_process_associations]).to match_array([
              {
                capi_process_guid: web_process_model_1.guid,
                diego_process_guids: ['some-diego-process-guid-1']
              },
              {
                capi_process_guid: web_process_model_2.guid,
                diego_process_guids: ['some-diego-process-guid-2']
              }
            ])
          end
        end
      end
    end
  end
end
