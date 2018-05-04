require 'spec_helper'
require 'jobs/services/service_binding_state_fetch'

module VCAP::CloudController
  module Jobs
    module Services
      RSpec.describe ServiceBindingStateFetch, job_context: :worker do
        let(:service_binding_operation) { ServiceBindingOperation.make(state: 'in progress') }
        let(:service_binding) do
          service_binding = ServiceBinding.make
          service_binding.service_binding_operation = service_binding_operation
          service_binding
        end

        let(:max_duration) { 10080 }
        let(:default_polling_interval) { 60 }
        let(:user) { User.make }
        let(:user_email) { 'fake@mail.foo' }
        let(:user_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
        let(:request_attrs) do
          {
            some_attr: 'some_value'
          }
        end

        before do
          TestConfig.override({
            broker_client_default_async_poll_interval_seconds: default_polling_interval,
            broker_client_max_async_poll_duration_minutes: max_duration,
          })
        end

        def run_job(job)
          Jobs::Enqueuer.new(job, { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        describe '#perform' do
          let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid, user_info, request_attrs) }
          let(:state) { 'in progress' }
          let(:description) { '10%' }
          let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

          before do
            allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
            allow(client).to receive(:fetch_service_binding_last_operation).and_return(last_operation: { state: state, description: description })
          end

          context 'when the last_operation state is succeeded' do
            let(:state) { 'succeeded' }
            let(:description) { '100%' }
            let(:binding_response) { {} }

            context 'it executes a job' do
              before do
                allow(client).to receive(:fetch_service_binding).with(service_binding).and_return(binding_response)
              end

              context 'and the broker returns valid credentials' do
                before do
                  # executes job and enqueues another job
                  run_job(job)
                end

                let(:binding_response) { { 'credentials': { 'a': 'b' } } }

                it 'should not enqueue another fetch job' do
                  expect(Delayed::Job.count).to eq 0
                end

                it 'should update the service binding' do
                  service_binding.reload
                  expect(service_binding.credentials).to eq({ 'a' => 'b' })
                end
              end

              context 'and the broker returns invalid credentials' do
                let(:broker_response) {
                  VCAP::Services::ServiceBrokers::V2::HttpResponse.new(
                    code: '200',
                    body: {}.to_json,
                  )
                }
                let(:binding_response) { { 'credentials': 'invalid' } }
                let(:response_malformed_exception) { VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerResponseMalformed.new(nil, nil, broker_response, nil) }

                before do
                  allow(client).to receive(:fetch_service_binding).with(service_binding).and_raise(response_malformed_exception)
                end

                it 'should not enqueue another fetch job' do
                  expect(client).to receive(:unbind).with(service_binding)

                  run_job(job)
                  expect(Delayed::Job.count).to eq 0
                end

                it 'should update the service binding last operation' do
                  expect(client).to receive(:unbind).with(service_binding)

                  run_job(job)
                  service_binding.reload
                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(service_binding.last_operation.description).
                    to eq('The service broker returned an invalid binding, an attempt to delete the binding from the broker has been made.')
                end
              end

              context 'and the broker returns credentials and something else' do
                before do
                  run_job(job)
                end

                let(:binding_response) { { 'credentials': { 'a': 'b' }, 'parameters': { 'c': 'd' } } }

                it 'should update the service binding' do
                  service_binding.reload
                  expect(service_binding.credentials).to eq({ 'a' => 'b' })
                end
              end

              context 'when user information is provided' do
                context 'and the last operation type is create' do
                  before do
                    run_job(job)
                  end

                  it 'should create audit event' do
                    event = Event.find(type: 'audit.service_binding.create')
                    expect(event).to be
                    expect(event.actee).to eq(service_binding.guid)
                    expect(event.metadata['request']).to have_key('some_attr')
                  end
                end
              end
            end

            context 'when the user has gone away' do
              it 'should not create an audit event' do
                allow(client).to receive(:fetch_service_binding).with(service_binding).and_return(binding_response)
                user.destroy

                run_job(job)

                expect(Event.find(type: 'audit.service_binding.create')).to be_nil
              end
            end
          end

          context 'when the broker responds to last_operation' do
            before do
              # executes job and enqueues another job
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceBindingStateFetch)
            end

            it 'updates the binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
              expect(service_binding.last_operation.description).to eq('10%')
            end

            context 'when the broker responds with failed last operation state' do
              let(:state) { 'failed' }
              let(:description) { 'something went wrong' }

              it 'updates the service binding last operation details' do
                service_binding.reload
                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('something went wrong')
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end

            context 'when enqueing the job reaches the max poll duration' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end

              it 'should mark the service instance operation as failed' do
                service_binding.reload

                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('Service Broker failed to bind within the required time.')
              end
            end
          end

          context 'when calling last operation responds with an error' do
            before do
              response = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 412, body: {})
              err = HttpResponseError.new('oops', 'uri', 'GET', response)
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)

              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end

            context 'and the max poll duration has been reached' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end
          end

          context 'when calling last operation times out' do
            before do
              err = VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout.new('uri', 'GET', {})
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when a database operation fails' do
            before do
              allow(ServiceBinding).to receive(:first).and_raise(Sequel::Error)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when the service binding has been purged' do
            let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new('bad-binding-guid', user_info, request_attrs) }

            it 'successfully exits the job' do
              # executes job and enqueues another job
              run_job(job)
            end

            it 'should not enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 0
            end
          end
        end
      end
    end
  end
end
