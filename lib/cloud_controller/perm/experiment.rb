require 'scientist'

module VCAP::CloudController
  module Perm
    class Experiment
      include Scientist::Experiment

      def initialize(name:, perm_enabled:, query_enabled:)
        @name = name
        @perm_enabled = perm_enabled
        @query_enabled = query_enabled
      end

      def enabled?
        @perm_enabled && @query_enabled
      end

      def publish(result) end
    end
  end
end
