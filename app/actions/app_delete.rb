module VCAP::CloudController
  class AppDelete
    attr_reader :user, :user_email

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_delete')
    end

    def delete(app_dataset)
      app_dataset.each do |app_model|
        PackageDelete.new.delete(packages_to_delete(app_model))
        DropletDelete.new.delete(droplets_to_delete(app_model))
        ProcessDelete.new(app_model.space, user, user_email).delete(app_model.processes_dataset)
        app_model.remove_all_routes

        @logger.info("Deleted app #{app_model.name} #{app_model.guid}")
        Event.create({
          type: 'audit.app.delete',
          actee: app_model.guid,
          actee_type: 'v3-app',
          actee_name: app_model.name,
          actor: @user.guid,
          actor_type: 'user',
          actor_name: @user_email,
          space_guid: app_model.space_guid,
          organization_guid: app_model.space.organization.guid,
          timestamp: Sequel::CURRENT_TIMESTAMP,
        })
      end

      app_dataset.destroy
    end

    private

    def packages_to_delete(app_model)
      app_model.packages_dataset.select(:"#{PackageModel.table_name}__guid", :"#{PackageModel.table_name}__id").all
    end

    def droplets_to_delete(app_model)
      app_model.droplets_dataset.select(:"#{DropletModel.table_name}__guid", :"#{DropletModel.table_name}__id").all
    end
  end
end
