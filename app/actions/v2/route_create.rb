module VCAP::CloudController
  module V2
    class RouteCreate
      def initialize(access_validator:, logger:)
        @access_validator = access_validator
        @logger = logger
      end

      def create_route(route_hash:)
        route = Route.db.transaction do
          r = Route.create_from_hash(route_hash)
          access_validator.validate_access(:create, r)

          r
        end

        if kubernetes_api_configured?
          route_crd_client.create_route(route)
        end

        route
      end

      private

      attr_reader :access_validator

      def route_crd_client
        @route_crd_client ||= CloudController::DependencyLocator.instance.route_crd_client
      end

      def kubernetes_api_configured?
        !!VCAP::CloudController::Config.config.get(:kubernetes, :host_url)
      end
    end
  end
end
