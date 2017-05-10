module VCAP::CloudController
  module Dea
    class Stager
      def initialize(app, config, message_bus, dea_pool, runners=CloudController::DependencyLocator.instance.runners)
        @config      = config
        @message_bus = message_bus
        @dea_pool    = dea_pool
        @runners     = runners
        @process     = app.web_process
      end

      def stage(staging_details)
        stager_task(staging_details.staging_guid).stage do |staging_result|
          @process.reload
          @runners.runner_for_app(@process).start(staging_result)
        end
      end

      def staging_complete(build, response)
        stager_task(build.guid).handle_http_response(response) do |staging_result|
          @process.reload
          @runners.runner_for_app(@process).start(staging_result)
        end
      end

      def stop_stage(_staging_guid)
        nil
      end

      private

      def stager_task(staging_guid)
        @task ||= AppStagerTask.new(@config, @message_bus, staging_guid, @dea_pool, CloudController::DependencyLocator.instance.blobstore_url_generator, @process)
      end
    end
  end
end
