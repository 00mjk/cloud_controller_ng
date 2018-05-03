module VCAP
  module CloudController
    module Perm
      class Permissions
        def initialize(perm_client:, user_id:, issuer:, roles:)
          @perm_client = perm_client
          @user_id = user_id
          @roles = roles
          @issuer = issuer
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_read_globally?
          roles.admin? || roles.admin_read_only? || roles.global_auditor?
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_read_secrets_globally?
          roles.admin? || roles.admin_read_only?
        end

        # Taken from lib/cloud_controller/permissions.rb
        def can_write_globally?
          roles.admin?
        end

        def can_read_from_org?(org_id)
          permissions = [
            { action: 'org.manager', resource: org_id },
            { action: 'org.auditor', resource: org_id },
            { action: 'org.user', resource: org_id },
            { action: 'org.billing_manager', resource: org_id },
          ]
          can_read_globally? || has_any_permission?(permissions)
        end

        def can_write_to_org?(org_id)
          permissions = [
            { action: 'org.manager', resource: org_id },
          ]

          can_write_globally? || has_any_permission?(permissions)
        end

        def can_read_from_space?(space_id, org_id)
          permissions = [
            { action: 'space.developer', resource: space_id },
            { action: 'space.manager', resource: space_id },
            { action: 'space.auditor', resource: space_id },
            { action: 'org.manager', resource: org_id },
          ]

          can_read_globally? || has_any_permission?(permissions)
        end

        def can_read_secrets_in_space?(space_id, org_id)
          permissions = [
            { action: 'space.developer', resource: space_id },
          ]

          can_read_secrets_globally? || has_any_permission?(permissions)
        end

        def can_write_to_space?(space_id)
          permissions = [
            { action: 'space.developer', resource: space_id },
          ]

          can_write_globally? || has_any_permission?(permissions)
        end

        def can_read_from_isolation_segment?(isolation_segment)
          can_read_globally? ||
            isolation_segment.spaces.any? { |space| can_read_from_space?(space.guid, space.organization.guid) } ||
            isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
        end

        def can_read_route?(space_id, org_id)
          permissions = [
            { action: 'space.developer', resource: space_id },
            { action: 'space.manager', resource: space_id },
            { action: 'space.auditor', resource: space_id },
            { action: 'org.manager', resource: org_id },
            { action: 'org.auditor', resource: org_id },
          ]

          can_read_globally? || has_any_permission?(permissions)
        end

        private

        attr_reader :perm_client, :user_id, :roles, :issuer

        def has_any_permission?(permissions)
          perm_client.has_any_permission?(permissions: permissions, user_id: user_id, issuer: issuer)
        end
      end
    end
  end
end
