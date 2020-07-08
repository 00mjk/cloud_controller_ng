require 'spec_helper'
require 'kubernetes/api_client'

RSpec.describe Kubernetes::ApiClient do
  let(:build_kube_client) { double(Kubeclient::Client) }
  let(:kpack_kube_client) { double(Kubeclient::Client) }
  let(:route_kube_client) { double(Kubeclient::Client) }
  subject(:k8s_api_client) do
    Kubernetes::ApiClient.new(
      build_kube_client: build_kube_client,
      kpack_kube_client: kpack_kube_client,
      route_kube_client: route_kube_client,
    )
  end

  context 'image resources' do
    describe '#create_image' do
      let(:resource_config) { { metadata: { name: 'resource-name' } } }

      it 'proxies call to kubernetes client with the same args' do
        allow(build_kube_client).to receive(:create_image).with(resource_config)

        subject.create_image(resource_config)

        expect(build_kube_client).to have_received(:create_image).with(resource_config).once
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:create_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.create_image(resource_config)
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#get_image' do
      let(:response) { double(Kubeclient::Resource) }

      it 'fetches the image from Kubernetes' do
        allow(build_kube_client).to receive(:get_image).with('name', 'namespace').and_return(response)

        image = subject.get_image('name', 'namespace')
        expect(image).to eq(response)
      end

      context 'when the image is not present' do
        it 'returns nil' do
          allow(build_kube_client).to receive(:get_image).with('name', 'namespace').and_raise(Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

          image = subject.get_image('name', 'namespace')
          expect(image).to be_nil
        end
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:get_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.get_image('name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#update_image' do
      let(:resource_config) { { metadata: { name: 'resource-name' } } }
      let(:response) { double(Kubeclient::Resource) }

      it 'proxies call to kubernetes client with the same args' do
        allow(build_kube_client).to receive(:update_image).with(resource_config)

        subject.update_image(resource_config)

        expect(build_kube_client).to have_received(:update_image).with(resource_config).once
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:update_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.update_image(resource_config)
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end

    describe '#delete_image' do
      it 'proxies call to kubernetes client with the same args' do
        expect(build_kube_client).to receive(:delete_image).with('resource-name', 'namespace')

        subject.delete_image('resource-name', 'namespace')
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(build_kube_client).to receive(:delete_image).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.delete_image('resource-name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end

        context 'when the image is not present' do
          it 'returns nil' do
            allow(build_kube_client).to receive(:delete_image).with('name', 'namespace').and_raise(
              Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

            image = subject.delete_image('name', 'namespace')
            expect(image).to be_nil
          end
        end
      end
    end
  end

  context 'route resources' do
    describe '#create_route' do
      let(:config_hash) { { metadata: { name: 'resource-name' } } }
      let(:resource_config) { Kubeclient::Resource.new(config_hash) }

      it 'proxies call to kubernetes client with the same args' do
        allow(route_kube_client).to receive(:create_route).with(resource_config)

        subject.create_route(resource_config)

        expect(route_kube_client).to have_received(:create_route).with(resource_config).once
      end

      context 'when there is an error' do
        before do
          allow(route_kube_client).to receive(:create_route).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))
        end

        context 'when the config is a Kubeclient::Resource' do
          let(:resource_config) { Kubeclient::Resource.new(config_hash) }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with symbol keys' do
          let(:resource_config) { config_hash.symbolize_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with string keys' do
          let(:resource_config) { config_hash.stringify_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the resource config is missing metadata' do
          let(:resource_config) { {} }

          it 'raises as an ApiError without a resource name' do
            expect {
              subject.create_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError)
          end
        end
      end
    end

    describe '#get_route' do
      let(:response) { double(Kubeclient::Resource) }

      it 'fetches the route resource from Kubernetes' do
        allow(route_kube_client).to receive(:get_route).with('resource-name', 'namespace').and_return(response)

        image = subject.get_route('resource-name', 'namespace')
        expect(image).to eq(response)
      end

      context 'when the route resource is not present' do
        it 'returns nil' do
          allow(route_kube_client).to receive(:get_route).with('resource-name', 'namespace').
            and_raise(Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

          image = subject.get_route('resource-name', 'namespace')
          expect(image).to be_nil
        end
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(route_kube_client).to receive(:get_route).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.get_route('resource-name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
        end
      end
    end

    describe '#update_route' do
      let(:config_hash) { { metadata: { name: 'resource-name' } } }
      let(:resource_config) { Kubeclient::Resource.new(config_hash) }

      let(:response) { double(Kubeclient::Resource) }

      it 'proxies call to kubernetes client with the same args' do
        allow(route_kube_client).to receive(:update_route).with(resource_config)

        subject.update_route(resource_config)

        expect(route_kube_client).to have_received(:update_route).with(resource_config).once
      end

      context 'when there is an error' do
        before do
          allow(route_kube_client).to receive(:update_route).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))
        end

        context 'when the config is a Kubeclient::Resource' do
          let(:resource_config) { Kubeclient::Resource.new(config_hash) }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with symbol keys' do
          let(:resource_config) { config_hash.symbolize_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the config is a hash with string keys' do
          let(:resource_config) { config_hash.stringify_keys }

          it 'raises as an ApiError that includes the resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
          end
        end

        context 'when the resource config is missing metadata' do
          let(:resource_config) { {} }

          it 'raises as an ApiError without a resource name' do
            expect {
              subject.update_route(resource_config)
            }.to raise_error(CloudController::Errors::ApiError)
          end
        end
      end
    end

    describe '#delete_route' do
      it 'proxies call to kubernetes client with the same args' do
        expect(route_kube_client).to receive(:delete_route).with('resource-name', 'namespace')

        subject.delete_route('resource-name', 'namespace')
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(route_kube_client).to receive(:delete_route).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.delete_route('resource-name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError, /resource-name/)
        end

        context 'when the route resource is not present' do
          it 'returns nil' do
            allow(route_kube_client).to receive(:delete_route).with('name', 'namespace').and_raise(
              Kubeclient::ResourceNotFoundError.new(404, 'images not found', '{"kind": "Status"}'))

            image = subject.delete_route('name', 'namespace')
            expect(image).to be_nil
          end
        end
      end
    end
  end

  context 'custom builder resources' do
    describe '#get_custom_builder' do
      let(:response) { double(Kubeclient::Resource) }

      it 'fetches the custom builder from Kubernetes' do
        allow(kpack_kube_client).to receive(:get_custom_builder).with('name', 'namespace').and_return(response)

        custombuilder = subject.get_custom_builder('name', 'namespace')
        expect(custombuilder).to eq(response)
      end

      context 'when the custombuilder is not present' do
        it 'returns nil' do
          allow(kpack_kube_client).to receive(:get_custom_builder).with('name', 'namespace').
            and_raise(Kubeclient::ResourceNotFoundError.new(404, 'custombuilders not found', '{"kind": "Status"}'))

          custombuilder = subject.get_custom_builder('name', 'namespace')
          expect(custombuilder).to be_nil
        end
      end

      context 'when there is an error' do
        it 'raises as an ApiError' do
          allow(kpack_kube_client).to receive(:get_custom_builder).and_raise(Kubeclient::HttpError.new(422, 'foo', 'bar'))

          expect {
            subject.get_custom_builder('name', 'namespace')
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end
  end
end
