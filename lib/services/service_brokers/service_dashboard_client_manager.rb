module VCAP::Services::ServiceBrokers
  class ServiceDashboardClientManager
    attr_reader :catalog, :errors, :service_broker

    def initialize(catalog, service_broker)
      @catalog        = catalog
      @service_broker = service_broker
      @errors         = VCAP::Services::ValidationErrors.new

      @services_requesting_dashboard_client = catalog.services.select(&:dashboard_client)
      @client_manager = VCAP::Services::UAA::UaaClientManager.new
      @differ = ServiceDashboardClientDiffer.new(service_broker)
    end

    def synchronize_clients
      return true unless cc_configured_to_modify_uaa_clients?

      validate_clients_are_available!
      return false unless errors.empty?

      changeset = differ.create_changeset(requested_clients, eligible_clients)

      service_broker.db.transaction(savepoint: true) do
        changeset.each(&:db_command)
        client_manager.modify_transaction(changeset)
      end

      true
    rescue VCAP::Services::UAA::UaaError => e
      raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerDashboardClientFailure", e.message)
    end

    private

    attr_reader :client_manager, :differ, :services_requesting_dashboard_client

    def eligible_clients
      clients_already_claimed_by_broker = VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(service_broker).all
      clients_that_can_be_claimed_by_broker = find_clients_for_services(services_with_existing_clients_in_uaa_available_to_broker)
      (clients_already_claimed_by_broker + clients_that_can_be_claimed_by_broker).uniq
    end

    def find_clients_for_services(services)
      services.map do |service|
        VCAP::CloudController::ServiceDashboardClient.find_client_by_uaa_id(service.dashboard_client['id'])
      end.compact
    end

    def services_with_existing_clients_in_uaa_available_to_broker
      @services_with_existing_clients_in_uaa_available_to_broker ||=
        services_with_existing_clients_in_uaa.select do |service|
          VCAP::CloudController::ServiceDashboardClient.client_can_be_claimed_by_broker?(
            service.dashboard_client['id'],
            service_broker
          )
        end
    end

    def services_with_existing_clients_in_uaa
      @services_with_existing_clients_in_uaa ||=
        begin
          existing_clients_in_uaa = client_manager.get_clients(requested_client_ids)
          ids_of_existing_clients_in_uaa = existing_clients_in_uaa.map { |client| client['client_id'] }

          services_requesting_dashboard_client.select { |s|
            ids_of_existing_clients_in_uaa.include?(s.dashboard_client['id'])
          }
        end
    end

    def services_whose_clients_are_claimed_by_another_broker
      services_with_existing_clients_in_uaa - services_with_existing_clients_in_uaa_available_to_broker
    end

    def validate_clients_are_available!
      services_whose_clients_are_claimed_by_another_broker.each do |catalog_service|
        errors.add_nested(catalog_service).add('Service dashboard client id must be unique')
      end
    end

    def requested_client_ids
      services_requesting_dashboard_client.map { |service| service.dashboard_client['id'] }
    end

    def cc_configured_to_modify_uaa_clients?
      uaa_client = VCAP::CloudController::Config.config[:uaa_client_name]
      uaa_client_secret = VCAP::CloudController::Config.config[:uaa_client_secret]
      uaa_client && uaa_client_secret
    end

    def requested_clients
      services_requesting_dashboard_client.map { |service| service.dashboard_client }
    end
  end
end
