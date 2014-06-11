module VCAP::CloudController
  class AppSecurityGroupRunningDefaultsController < RestController::ModelController
    def self.model
      AppSecurityGroup
    end

    def self.path
      "#{ROUTE_PREFIX}/config/running_security_groups"
    end

    def self.not_found_exception(guid)
      Errors::ApiError.new_from_details("AppSecurityGroupRunningDefaultInvalid", guid)
    end

    define_attributes do
      attribute :app_security_group_guid, String
    end

    define_messages

    get path, :enumerate

    post path_guid, :create
    def create(guid)
      obj = find_guid_and_validate_access(:update, guid)

      model.db.transaction(savepoint: true) do
        obj.lock!
        obj.update_from_hash({"running_default" => true})
      end

      [
          HTTP::CREATED,
          object_renderer.render_json(self.class, obj, @opts)
      ]
    end

    delete path_guid, :delete
    def delete(guid)
      obj = find_guid_and_validate_access(:delete, guid)

      model.db.transaction(savepoint: true) do
        obj.lock!
        obj.update_from_hash({"running_default" => false})
      end

      [
          HTTP::NO_CONTENT
      ]
    end

    def read(_)
      raise Errors::ApiError.new_from_details("NotAuthorized") unless roles.admin?
      super
    end

    def enumerate
      raise Errors::ApiError.new_from_details("NotAuthorized") unless roles.admin?
      super
    end

    private

    def filter_dataset(dataset)
      dataset.filter(running_default: true)
    end
  end
end