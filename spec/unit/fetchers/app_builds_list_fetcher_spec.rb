require 'spec_helper'
require 'messages/builds_list_message'
require 'fetchers/app_builds_list_fetcher'

module VCAP::CloudController
  RSpec.describe AppBuildsListFetcher do
    let(:space1) { FactoryBot.create(:space) }
    let(:space2) { FactoryBot.create(:space) }
    let(:space3) { FactoryBot.create(:space) }
    let(:org_1_guid) { space1.organization.guid }
    let(:org_2_guid) { space2.organization.guid }
    let(:org_3_guid) { space3.organization.guid }
    let(:app_in_space1) { FactoryBot.create(:app, space: space1, guid: 'app1') }
    let(:app2_in_space1) { FactoryBot.create(:app, space: space1, guid: 'app2') }
    let(:app3_in_space2) { FactoryBot.create(:app, space: space2, guid: 'app3') }
    let(:app4_in_space3) { FactoryBot.create(:app, space: space3, guid: 'app4') }

    let!(:staged_build_for_app1_space1) { FactoryBot.create(:build, app_guid: app_in_space1.guid, state: BuildModel::STAGED_STATE) }
    let!(:failed_build_for_app1_space1) { FactoryBot.create(:build, app_guid: app_in_space1.guid, state: BuildModel::FAILED_STATE) }

    let!(:staged_build_for_app2_space1) { FactoryBot.create(:build, app_guid: app2_in_space1.guid, state: BuildModel::STAGED_STATE) }

    let!(:staging_build_for_app3_space2) { FactoryBot.create(:build, app_guid: app3_in_space2.guid, state: BuildModel::STAGING_STATE) }
    let!(:staging_build_for_app4_space3) { FactoryBot.create(:build, app_guid: app4_in_space3.guid, state: BuildModel::STAGING_STATE) }

    subject(:fetcher) { AppBuildsListFetcher.new(app_guid, message) }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { AppBuildsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      context 'when looking at app_in_space1' do
        let(:app_guid) { app_in_space1.guid }

        it 'returns a Sequel::Dataset' do
          results = fetcher.fetch_all
          expect(results).to be_a(Sequel::Dataset)
        end

        it 'returns all of the builds' do
          results = fetcher.fetch_all
          expect(results.count).to eq(2)
          expect(results.all).to match_array([staged_build_for_app1_space1, failed_build_for_app1_space1])
        end

        context 'filtering states' do
          let(:filters) { { states: [BuildModel::STAGED_STATE] } }

          it 'returns all of the builds with the requested states' do
            results = fetcher.fetch_all.all
            expect(results).to match_array([staged_build_for_app1_space1])
          end
        end
      end
    end
  end
end
