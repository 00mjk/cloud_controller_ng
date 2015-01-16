module VCAP::CloudController
  module Jobs
    class RequestJob
      attr_accessor :job, :request_id

      def initialize(job, request_id)
        @job = job
        @request_id = request_id
      end

      def perform
        current_request_id = ::VCAP::Request.current_id
        begin
          ::VCAP::Request.current_id = request_id
          job.perform
        ensure
          ::VCAP::Request.current_id = current_request_id
        end
      end

      def max_attempts
        job.max_attempts
      end
    end
  end
end
