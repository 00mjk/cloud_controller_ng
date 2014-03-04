require 'models/services/service_broker/v2/service_dashboard_client_manager'
require 'models/services/service_brokers/validation_errors_formatter'

module VCAP::CloudController
  class ServiceBrokerRegistration
    attr_reader :broker

    def initialize(broker)
      @broker = broker
    end

    def save
      return unless broker.valid?

      catalog_hash = broker.client.catalog
      catalog      = build_catalog(catalog_hash)

      manager = ServiceBroker::V2::ServiceDashboardClientManager.new(catalog)
      unless manager.create_service_dashboard_clients
        formatter = ServiceBrokers::ValidationErrorsFormatter.new
        raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", formatter.format(manager.errors))
      end

      broker.db.transaction(savepoint: true) do
        broker.save
        catalog.sync_services_and_plans
      end

      return self
    end

    def build_catalog(catalog_hash)
      catalog = VCAP::CloudController::ServiceBroker::V2::Catalog.new(broker, catalog_hash)
      raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", catalog.error_text) unless catalog.valid?
      catalog
    end

    def errors
      broker.errors
    end
  end
end
