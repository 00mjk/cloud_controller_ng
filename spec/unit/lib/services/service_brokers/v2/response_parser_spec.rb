require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      describe ResponseParser do
        let(:url) { 'my.service-broker.com' }
        subject(:parsed_response) { ResponseParser.new(url).parse(method, path, response) }

        let(:logger) { instance_double(Steno::Logger, warn: nil) }
        before do
          allow(Steno).to receive(:logger).and_return(logger)
        end

        describe '#parse' do
          let(:response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
          let(:path) { '/v2/service_instances' }
          let(:body) { '{}' }

          before do
            allow(response).to receive(:code).and_return(code)
            allow(response).to receive(:body).and_return(body)
            allow(response).to receive(:message).and_return('message')
          end

          context 'when the status code is 200' do
            let(:code) { 200 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is partial json response' do
                let(:body) { '""' }
                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'the response is invalid json' do
                let(:body) { 'dfgh' }
                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                  expect(logger).to have_received(:warn)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              let(:body) do
                {
                  dashboard_url: 'url.com/dashboard',
                  last_operation: {
                    state: state,
                    description: 'description',
                  },
                }.to_json
              end

              context 'and the state is `succeeded`' do
                let(:state) { 'succeeded' }
                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => 'succeeded',
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is `nil`' do
                let(:state) { nil }
                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => nil,
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is `in progress`' do
                let(:state) { nil }
                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => nil,
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is `failed`' do
                let(:state) { 'failed' }
                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => 'failed',
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is not recognized' do
                let(:state) { 'fake-state' }
                it 'raises a ServiceBrokerResponseMalformed' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the request is for a binding' do
                let(:path) { '/v2/service_instances/guid/service_bindings/some-other-guid' }
                let(:state) { 'succeeded' }

                it 'does not propogate a state or description fields if it is present' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                  })
                end
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              let(:body) do
                {
                  dashboard_url: 'url.com/dashboard',
                  last_operation: {
                    state: state,
                    description: 'description',
                  },
                }.to_json
              end

              context 'and the state is recognized' do
                let(:state) { 'in progress' }

                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => 'in progress',
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is not recgonized' do
                let(:state) { 'fake-state' }
                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              let(:body) { {}.to_json }

              it 'returns response_hash' do
                expect(parsed_response).to eq({})
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              let(:body) { {}.to_json }

              it 'returns response_hash' do
                expect(parsed_response).to eq({})
              end
            end
          end

          context 'when the status code is 201' do
            let(:code) { 201 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' }
                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              let(:body) do
                {
                  dashboard_url: 'url.com/dashboard',
                  last_operation: {
                    state: state,
                    description: 'description',
                  },
                }.to_json
              end

              context 'and the state is `succeeded`' do
                let(:state) { 'succeeded' }
                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => 'succeeded',
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is nil' do
                let(:state) { nil }
                it 'returns response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => nil,
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is `failed`' do
                let(:state) { 'failed' }

                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the state is `in progress`' do
                let(:state) { 'in progress' }

                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the state is unrecognized' do
                let(:state) { 'fake-state' }

                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the request is for bindings' do
                let(:state) { 'whatever' }
                let(:path) { '/v2/service_instances/guid/service_bindings/some-other-guid' }

                it 'does not propagade state and description fields' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                  })
                end
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 202' do
            let(:code) { 202 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' }
                it 'raises a ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              let(:body) do
                {
                  dashboard_url: 'url.com/dashboard',
                  last_operation: {
                    state: state,
                    description: 'description',
                  },
                }.to_json
              end

              context 'and the state is `succeeded`' do
                let(:state) { 'succeeded' }

                it 'should raise ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the state is `failed`' do
                let(:state) { 'failed' }

                it 'should raise ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the state is `in progress`' do
                let(:state) { 'in progress' }

                it 'should return the response_hash' do
                  expect(parsed_response).to eq({
                    'dashboard_url' => 'url.com/dashboard',
                    'last_operation' => {
                      'state' => 'in progress',
                      'description' => 'description',
                    },
                  })
                end
              end

              context 'and the state is nil' do
                let(:state) { nil }

                it 'should raise ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the state is unrecognized' do
                let(:state) { :unrecognized }

                it 'should raise ServiceBrokerResponseMalformed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
                end
              end

              context 'and the request is for bindings' do
                let(:state) { 'in progress' }
                let(:path) { '/v2/service_instances/guid/service_bindings/some-other-guid' }

                it 'raises a ServiceBrokerBadResponse error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
                end
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              let(:body) do
                {
                  dashboard_url: 'url.com/dashboard',
                  last_operation: {
                    state: 'in progress',
                    description: 'description',
                  },
                }.to_json
              end

              it 'raises a ServiceBrokerBadResponse error' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'in progress',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is other 2xx' do
            let(:code) { 204 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' }
                it 'raises a ServiceBrokerBadResponse error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 3xx' do
            let(:code) { 302 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerBadResponse error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 401' do
            let(:code) { 401 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end
          end

          context 'when the status code is 409' do
            let(:code) { 409 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerConflict error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerConflict)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerConflict error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerConflict)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 410' do
            let(:code) { 410 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerBadResponse error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'returns nil and logs a warning' do
                expect(parsed_response).to be_nil
                expect(logger).to have_received(:warn)
              end
            end
          end

          context 'when the status code is 422' do
            let(:code) { 422 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerBadResponse error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }

              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end

              context 'when the error field is `AsyncRequired`' do
                let(:body) { { error: 'AsyncRequired' }.to_json }
                it 'raises an AsyncRequired error' do
                  expect { parsed_response }.to raise_error(Errors::AsyncRequired)
                end
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is other 4xx' do
            let(:code) { 404 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerRequestRejected error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end
          end

          context 'when the status code is 5xx' do
            let(:code) { 500 }

            context 'and regardless of the method' do
              let(:method) { :put }

              context 'the response is not a valid json object' do
                let(:body) { '""' } # AppDirect likes to return this
                it 'raises a ServiceBrokerBadResponse error' do
                  expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
                end
              end
            end

            context 'and the method is put' do
              let(:method) { :put }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is get' do
              let(:method) { :get }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is patch' do
              let(:method) { :patch }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end

            context 'and the method is delete' do
              let(:method) { :delete }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end
        end

        describe '#parse_state_fetch' do
          subject(:parsed_response) { ResponseParser.new(url).parse_fetch_state(method, path, response) }
          let(:response) { instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse) }
          let(:path) { '/v2/service_instances' }
          let(:body) { '{}' }

          before do
            allow(response).to receive(:code).and_return(code)
            allow(response).to receive(:body).and_return(body)
            allow(response).to receive(:message).and_return('message')
          end

          context 'when the status code is 200' do
            let(:code) { 200 }

            let(:method) { :get }
            let(:body) do
              {
                dashboard_url: 'url.com/dashboard',
                last_operation: {
                  state: state,
                  description: 'description',
                },
              }.to_json
            end

            context 'and the state is recognized' do
              let(:state) { 'in progress' }

              it 'returns response_hash' do
                expect(parsed_response).to eq({
                  'dashboard_url' => 'url.com/dashboard',
                  'last_operation' => {
                    'state' => 'in progress',
                    'description' => 'description',
                  },
                })
              end
            end

            context 'and the state is not recgonized' do
              let(:state) { 'fake-state' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'and the last_operation is not present' do
              let(:body) { { state: 'state-in-incorrect-location' }.to_json }
              it 'raises ServiceBrokerResponseMalformed' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is 201' do
            let(:code) { 201 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is 202' do
            let(:code) { 202 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerResponseMalformed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerResponseMalformed)
              end
            end
          end

          context 'when the status code is other 2xx' do
            let(:code) { 204 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' }
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 3xx' do
            let(:code) { 302 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 401' do
            let(:code) { 401 }
            let(:method) { :get }
            it 'raises a ServiceBrokerApiAuthenticationFailed error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerApiAuthenticationFailed error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerApiAuthenticationFailed)
              end
            end
          end

          context 'when the status code is 409' do
            let(:code) { 409 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 410' do
            let(:code) { 410 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is 422' do
            let(:code) { 422 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end

          context 'when the status code is other 4xx' do
            let(:code) { 404 }
            let(:method) { :get }

            it 'raises a ServiceBrokerRequestRejected error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerRequestRejected error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerRequestRejected)
              end
            end
          end

          context 'when the status code is 5xx' do
            let(:code) { 500 }
            let(:method) { :get }

            it 'raises a ServiceBrokerBadResponse error' do
              expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
            end

            context 'the response is not a valid json object' do
              let(:body) { '""' } # AppDirect likes to return this
              it 'raises a ServiceBrokerBadResponse error' do
                expect { parsed_response }.to raise_error(Errors::ServiceBrokerBadResponse)
              end
            end
          end
        end
      end
    end
  end
end
