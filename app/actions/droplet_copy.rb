module VCAP::CloudController
  class DropletCopy
    CLONED_ATTRIBUTES = [
      :buildpack_receipt_buildpack_guid,
      :detected_start_command,
      :salt,
      :environment_variables,
      :process_types,
      :buildpack_receipt_buildpack,
      :buildpack_receipt_stack_name,
      :execution_metadata,
      :memory_limit,
      :disk_limit,
      :docker_receipt_image
    ].freeze

    def initialize(source_droplet)
      @source_droplet = source_droplet
    end

    def copy(destination_app_guid)
      validate!
      new_droplet = DropletModel.new(state: DropletModel::PENDING_STATE, app_guid: destination_app_guid)

      # Needed to execute serializers and deserializers correctly on source and destination models
      CLONED_ATTRIBUTES.each do |attr|
        new_droplet.send("#{attr}=", @source_droplet.send(attr))
      end

      DropletModel.db.transaction do
        new_droplet.save

        if @source_droplet.buildpack?
          BuildpackLifecycleDataModel.create(droplet_guid: new_droplet.guid,
                                             stack: @source_droplet.buildpack_lifecycle_data.stack,
                                             buildpack: @source_droplet.buildpack_lifecycle_data.buildpack)

          copy_job = Jobs::V3::DropletBitsCopier.new(@source_droplet.guid, new_droplet.guid)
          Jobs::Enqueuer.new(copy_job, queue: 'cc-generic').enqueue
        end
      end
      new_droplet.reload
    end

    def validate!
      if @source_droplet.docker?
        raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', 'Copy droplet', 'Not supported for docker droplets')
      end
    end
  end
end
