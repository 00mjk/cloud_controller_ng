require 'scientist'

module VCAP::CloudController
  module Science
    class Experiment < Scientist::Default
      include Scientist::Experiment

      def initialize(name:, enabled:)
        super(name)
        @enabled = enabled
      end

      def enabled?
        @enabled
      end

      def publish(result)
        if result.matched?
          logger.debug(
            'matched',
            {
              context: @_scientist_context,
              control: observation_payload(result.control),
              candidate: observation_payload(result.candidates.first),
            }
          )
        else
          logger.info(
            'mismatched',
            {
              context: @_scientist_context,
              control: observation_payload(result.control),
              candidate: observation_payload(result.candidates.first),
            })
        end
      end

      private

      attr_reader :enabled

      def logger
        @logger ||= Steno.logger("science.#{name}")
      end

      def observation_payload(observation)
        if observation.raised?
          {
            exception: observation.exception.class,
            message: observation.exception.message,
            backtrace: observation.exception.backtrace
          }
        else
          {
            value: observation.cleaned_value
          }
        end
      end
    end
  end
end
