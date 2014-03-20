module VCAP::CloudController::ServiceBrokers::V2
  class DeleteClientCommand
    attr_reader :client_id

    def initialize(opts)
      @client_id = opts.fetch(:client_id)
      @client_manager = opts.fetch(:client_manager)
    end

    def apply!
      client_manager.delete(client_id)
      client = VCAP::CloudController::ServiceDashboardClient.find(uaa_id: client_id)
      client.destroy
    end

    private

    attr_reader :client_manager
  end
end
