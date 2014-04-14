module VCAP::Services::SSO
  class DashboardClientManager
    attr_reader :errors, :service_broker, :warnings

    REQUESTED_FEATURE_DISABLED_WARNING = 'Warning: This broker includes configuration for a dashboard client. Auto-creation of OAuth2 clients has been disabled in this Cloud Foundry instance. The broker catalog has been updated but its dashboard client configuration will be ignored.'

    def initialize(service_broker)
      @service_broker = service_broker
      @errors         = VCAP::Services::ValidationErrors.new
      @warnings       = []

      @client_manager = VCAP::Services::SSO::UAA::UaaClientManager.new
      @differ         = DashboardClientDiffer.new(service_broker)
    end

    def synchronize_clients_with_catalog(catalog)
      requested_clients = catalog.services.map(&:dashboard_client).compact

      unless cc_configured_to_modify_uaa_clients?
        warnings << REQUESTED_FEATURE_DISABLED_WARNING unless requested_clients.empty?
        return true
      end

      existing_db_clients = VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(service_broker).all

      client_ids_already_in_uaa = get_client_ids_already_in_uaa(existing_db_clients, requested_clients)
      unclaimable_ids           = get_client_ids_that_cannot_be_claimed(client_ids_already_in_uaa)

      if !unclaimable_ids.empty?
        populate_uniqueness_errors(catalog, unclaimable_ids)
        return false
      end

      available_clients = client_ids_already_in_uaa.map do |id|
        VCAP::CloudController::ServiceDashboardClient.find_client_by_uaa_id(id)
      end

      existing_clients = (existing_db_clients + available_clients).uniq

      claim_clients_and_update_uaa(requested_clients, existing_clients, client_ids_already_in_uaa)

      true
    end

    def remove_clients_for_broker
      return unless cc_configured_to_modify_uaa_clients?

      requested_clients    = [] # request no clients
      existing_db_clients  = VCAP::CloudController::ServiceDashboardClient.find_clients_claimed_by_broker(service_broker)
      existing_uaa_clients = get_client_ids_already_in_uaa(existing_db_clients, requested_clients)

      claim_clients_and_update_uaa(requested_clients, existing_db_clients, existing_uaa_clients)
    end

    def has_warnings?
      warnings.empty? == false
    end

    private

    attr_reader :client_manager, :differ

    def claim_clients_and_update_uaa(requested_clients, existing_db_clients, existing_uaa_clients)
      db_changeset  = differ.create_db_changeset(requested_clients, existing_db_clients)
      uaa_changeset = differ.create_uaa_changeset(requested_clients, existing_uaa_clients)

      begin
        service_broker.db.transaction(savepoint: true) do
          db_changeset.each(&:db_command)
          client_manager.modify_transaction(uaa_changeset)
        end
      rescue VCAP::Services::SSO::UAA::UaaError => e
        raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerDashboardClientFailure", e.message)
      end
    end

    def get_client_ids_already_in_uaa(existing_db_clients, requested_clients)
      requested_client_ids    = requested_clients.map { |c| c['id'] }
      existing_db_client_ids  = existing_db_clients.map(&:uaa_id)

      clients_already_in_uaa = client_manager.get_clients(requested_client_ids + existing_db_client_ids).map { |c| c['client_id'] }
      clients_already_in_uaa
    end

    def get_client_ids_that_cannot_be_claimed(clients)
      unclaimable_ids = []
      clients.each do |id|
        claimable = VCAP::CloudController::ServiceDashboardClient.client_can_be_claimed_by_broker?(id, service_broker)

        if !claimable
          unclaimable_ids << id
        end
      end
      unclaimable_ids
    end

    def populate_uniqueness_errors(catalog, non_unique_ids)
      catalog.services.each do |service|
        if service.dashboard_client && non_unique_ids.include?(service.dashboard_client['id'])
          errors.add_nested(service).add('Service dashboard client id must be unique')
        end
      end
    end

    def cc_configured_to_modify_uaa_clients?
      uaa_client = VCAP::CloudController::Config.config[:uaa_client_name]
      uaa_client_secret = VCAP::CloudController::Config.config[:uaa_client_secret]
      uaa_client && uaa_client_secret
    end
  end
end
