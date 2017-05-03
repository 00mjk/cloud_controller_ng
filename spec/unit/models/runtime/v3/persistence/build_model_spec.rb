# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildModel do
    let(:build_model) { BuildModel.make }
    let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(build: build_model) }

    before do
      build_model.buildpack_lifecycle_data = lifecycle_data
      build_model.save
    end

    describe '#lifecycle_type' do
      it 'returns the string "buildpack" if buildpack_lifecycle_data is on the model' do
        expect(build_model.lifecycle_type).to eq('buildpack')
      end

      it 'returns the string "docker" if there is no buildpack_lifecycle_data is on the model' do
        build_model.buildpack_lifecycle_data = nil
        build_model.save

        expect(build_model.lifecycle_type).to eq('docker')
      end
    end

    describe '#lifecycle_data' do
      it 'returns buildpack_lifecycle_data if it is on the model' do
        expect(build_model.lifecycle_data).to eq(lifecycle_data)
      end

      it 'is a persistable hash' do
        expect(build_model.reload.lifecycle_data.buildpack).to eq(lifecycle_data.buildpack)
        expect(build_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
      end

      it 'returns a docker lifecycle model if there is no buildpack_lifecycle_model' do
        build_model.buildpack_lifecycle_data = nil
        build_model.save

        expect(build_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
      end
    end
  end
end
