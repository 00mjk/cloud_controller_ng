require 'perm'

module VCAP::CloudController
  module Perm
    class Client
      def self.build_from_config(config, file_opener)
        hostname = config.get(:perm, :hostname)
        port = config.get(:perm, :port)
        enabled = config.get(:perm, :enabled)
        ca_cert_path = config.get(:perm, :ca_cert_path)
        timeout = config.get(:perm, :timeout_in_milliseconds) / 1000.0
        trusted_cas = []
        if enabled
          trusted_cas << file_opener.open(ca_cert_path).read
        end

        self.new(hostname: hostname, port: port, enabled: enabled, trusted_cas: trusted_cas, logger_name: 'perm.client', timeout: timeout)
      end

      def initialize(hostname:, port:, enabled:, trusted_cas:, logger_name:, timeout:)
        @hostname = hostname
        @port = port
        @trusted_cas = trusted_cas
        @enabled = enabled
        @logger_name = logger_name
        @timeout = timeout
      end

      # When this object is passed across the boundary to DelayedJob it is serialized in the database
      # and then automatically rehydrated on the other side
      # This does not work in our case because
      # a) The gRPC connection is broken
      # b) The logger's Syslog logger cannot be serialized
      # Instead, provide a custom rehydrate method that returns a new object
      # and do this when performing the DelayedJob
      def rehydrate
        Client.new(hostname: hostname, port: port, enabled: enabled, trusted_cas: trusted_cas, logger_name: logger_name, timeout: timeout)
      end

      def create_org_role(role:, org_id:)
        create_role(org_role(role, org_id))
      end

      def delete_org_role(role:, org_id:)
        delete_role(org_role(role, org_id))
      end

      def assign_org_role(role:, org_id:, user_id:, issuer:)
        assign_role(role: org_role(role, org_id), user_id: user_id, issuer: issuer)
      end

      def unassign_org_role(role:, org_id:, user_id:, issuer:)
        unassign_role(role: org_role(role, org_id), user_id: user_id, issuer: issuer)
      end

      def create_space_role(role:, space_id:)
        create_role(space_role(role, space_id))
      end

      def delete_space_role(role:, space_id:)
        delete_role(space_role(role, space_id))
      end

      def assign_space_role(role:, space_id:, user_id:, issuer:)
        assign_role(role: space_role(role, space_id), user_id: user_id, issuer: issuer)
      end

      def unassign_space_role(role:, space_id:, user_id:, issuer:)
        unassign_role(role: space_role(role, space_id), user_id: user_id, issuer: issuer)
      end

      def unassign_roles(org_ids: [], space_ids: [], user_id:, issuer:)
        space_ids.each do |space_id|
          VCAP::CloudController::SpacesController::ROLE_NAMES.each do |role|
            unassign_space_role(role: role, space_id: space_id, user_id: user_id, issuer: issuer)
          end
        end

        org_ids.each do |org_id|
          VCAP::CloudController::OrganizationsController::ROLE_NAMES.each do |role|
            unassign_org_role(role: role, org_id: org_id, user_id: user_id, issuer: issuer)
          end
        end
      end

      private

      attr_reader :hostname, :port, :enabled, :trusted_cas, :logger_name, :timeout

      def client
        @client ||= CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: trusted_cas, timeout: timeout)
      end

      def org_role(role, org_id)
        "org-#{role}-#{org_id}"
      end

      def space_role(role, space_id)
        "space-#{role}-#{space_id}"
      end

      def create_role(role)
        if enabled
          begin
            client.create_role(role)
          rescue GRPC::AlreadyExists
            logger.debug('create-role.role-already-exists', role: role)
          rescue GRPC::BadStatus => e
            logger.error('create-role.bad-status', role: role, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          end
        end
      end

      def delete_role(role)
        if enabled
          begin
            client.delete_role(role)
          rescue GRPC::NotFound
            logger.debug('delete-role.role-does-not-exist', role: role)
          rescue GRPC::BadStatus => e
            logger.error('delete-role.bad-status', role: role, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          end
        end
      end

      def assign_role(role:, user_id:, issuer:)
        if enabled
          begin
            client.assign_role(role_name: role, actor_id: user_id, issuer: issuer)
          rescue GRPC::AlreadyExists
            logger.debug('assign-role.assignment-already-exists', role: role, user_id: user_id, issuer: issuer)
          rescue GRPC::NotFound
            logger.error('assign-role.role-does-not-exist', role: role, user_id: user_id, issuer: issuer)
          rescue GRPC::BadStatus => e
            logger.error('assign-role.bad-status', role: role, user_id: user_id, issuer: issuer, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          end
        end
      end

      def unassign_role(role:, user_id:, issuer:)
        if enabled
          begin
            client.unassign_role(role_name: role, actor_id: user_id, issuer: issuer)
          rescue GRPC::NotFound => e
            logger.error('unassign-role.resource-not-found', role: role, user_id: user_id, issuer: issuer, details: e.details, metadata: e.metadata)
          rescue GRPC::BadStatus => e
            logger.error('unassign-role.bad-status', role: role, user_id: user_id, issuer: issuer, status: e.class.to_s, code: e.code, details: e.details, metadata: e.metadata)
          end
        end
      end

      # Can't be cached because the Syslog logger doesn't deserialize correctly for delayed jobs :(
      def logger
        Steno.logger(logger_name)
      end
    end
  end
end
