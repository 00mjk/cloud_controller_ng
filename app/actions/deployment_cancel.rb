module VCAP::CloudController
  class DeploymentCancel
    class Error < StandardError; end
    class InvalidStatus < Error; end
    class SetCurrentDropletError < Error; end

    class << self
      def cancel(deployment:, user_audit_info:)
        deployment.db.transaction do
          deployment.lock!
          reject_invalid_status!(deployment) unless valid_status?(deployment)

          begin
            AppAssignDroplet.new(user_audit_info).assign(deployment.app, deployment.previous_droplet)
          rescue AppAssignDroplet::Error => e
            raise SetCurrentDropletError.new(e)
          end
          record_audit_event(deployment, user_audit_info)
          deployment.update(
            state: DeploymentModel::CANCELING_STATE,
            status_value: DeploymentModel::CANCELING_STATUS_VALUE
          )
        end
      end

      private

      def valid_status?(deployment)
        valid_statuses_for_cancel = [DeploymentModel::DEPLOYING_STATUS_VALUE,
                                    DeploymentModel::CANCELING_STATUS_VALUE]
        valid_statuses_for_cancel.include?(deployment.status_value)
      end

      def reject_invalid_status!(deployment)
        raise InvalidStatus.new("Cannot cancel a #{deployment.status_value} deployment")
      end

      def record_audit_event(deployment, user_audit_info)
        app = deployment.app
        Repositories::DeploymentEventRepository.record_cancel(
          deployment,
          deployment.droplet,
          user_audit_info,
          app.name,
          app.space_guid,
          app.space.organization_guid,
        )
      end
    end
  end
end
