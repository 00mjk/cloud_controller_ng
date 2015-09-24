require 'cloud_controller/diego/staging_completion_handler_base'

module VCAP::CloudController
  module Diego
    module Traditional
      module V3
        class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandlerBase
          def initialize(runners)
            super(runners, Steno.logger('cc.stager'), 'diego.staging.v3.')
          end

          def self.success_parser
            @staging_response_schema ||= Membrane::SchemaParser.parse do
              {
                result: {
                  execution_metadata: String,
                  lifecycle_type:     'buildpack',
                  lifecycle_metadata: {
                    buildpack_key:      String,
                    detected_buildpack: String,
                  },
                  process_types:      dict(Symbol, String)
                }
              }
            end
          end

          private

          def handle_failure(droplet, payload)
            error   = payload[:error][:id] || 'StagingError'
            message = payload[:error][:message]

            droplet.class.db.transaction do
              droplet.lock!

              droplet.state = DropletModel::FAILED_STATE
              droplet.error = "#{error} - #{message}"
              droplet.save
            end

            Loggregator.emit_error(droplet.guid, "Failed to stage droplet: #{payload[:error][:message]}")
          end

          def handle_success(droplet, payload)
            begin
              self.class.success_parser.validate(payload)
            rescue Membrane::SchemaValidationError => e
              logger.error('diego.staging.success.invalid-message', staging_guid: droplet.guid, payload: payload, error: e.to_s)
              raise Errors::ApiError.new_from_details('InvalidRequest', payload)
            end

            begin
              save_staging_result(droplet, payload)
            rescue => e
              logger.error(@logger_prefix + 'saving-staging-result-failed', staging_guid: droplet.guid, response: payload, error: e.message)
            end
          end

          def save_staging_result(droplet, payload)
            lifecycle_data = payload[:result][:lifecycle_metadata]

            process_types = []
            payload[:result][:process_types].each do |type, command|
              process_types << "#{type}: #{command}"
            end

            droplet.class.db.transaction do
              droplet.lock!
              droplet.procfile  = process_types.join("\n")
              droplet.buildpack = lifecycle_data[:detected_buildpack] unless lifecycle_data[:detected_buildpack].blank?
              droplet.mark_as_staged

              droplet.save_changes(raise_on_save_failure: true)
            end
          end
        end
      end
    end
  end
end
