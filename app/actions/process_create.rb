require 'repositories/process_event_repository'
require 'models/helpers/process_types'

module VCAP::CloudController
  class ProcessCreate
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(app, args)
      type = args[:type]
      attrs = args.merge({
        diego:             true,
        instances:         args[:instances] || default_instance_count(type),
        health_check_type: default_health_check_type(type),
        metadata:          {},
      })
      attrs[:guid] = app.guid if type == ProcessTypes::WEB

      process = nil
      app.class.db.transaction do
        process = app.add_process(attrs)
        Repositories::ProcessEventRepository.record_create(process, @user_audit_info)
      end

      process
    end

    private

    def default_health_check_type(type)
      type == ProcessTypes::WEB ? 'port' : 'process'
    end

    def default_instance_count(type)
      type == ProcessTypes::WEB ? 1 : 0
    end
  end
end
