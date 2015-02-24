module VCAP::CloudController
  class ServiceInstanceUpdater
    def initialize(services_event_repository, access_validator, logger)
      @services_event_repository = services_event_repository
      @access_validator = access_validator
      @logger = logger
    end

    def update_service_instance(service_instance, request_attrs, params)
      @access_validator.validate_access(:read_for_update, service_instance)
      @access_validator.validate_access(:update, service_instance)
      validate_update_request(service_instance, request_attrs, params)

      err = nil
      service_instance.lock_by_failing_other_operations('update') do
        attributes_to_update = {}
        if request_attrs['service_plan_guid']
          new_plan = ServicePlan.find(guid: request_attrs['service_plan_guid'])
          return if new_plan == service_instance.service_plan

          attributes_to_update, err = service_instance.client.update_service_plan(
            service_instance,
            new_plan,
            accepts_incomplete: accepts_incomplete?(params),
            event_repository_opts: {
              user: SecurityContext.current_user,
              user_email: SecurityContext.current_user_email
            },
            request_attrs: request_attrs,
          )
        elsif request_attrs['name']
          attributes_to_update = {
            name: request_attrs['name'],
            last_operation: {
              state: 'succeeded'
            }
          }
        end

        service_instance.save_with_operation(attributes_to_update)
      end

      raise err if err

      if !accepts_incomplete?(params) || service_instance.last_operation.state != 'in progress'
        @services_event_repository.record_service_instance_event(:update, service_instance, request_attrs)
      end
    end

    private

    def validate_update_request(service_instance, request_attrs, params)
      if request_attrs['space_guid'] && request_attrs['space_guid'] != service_instance.space.guid
        raise Errors::ApiError.new_from_details('ServiceInstanceSpaceChangeNotAllowed')
      end

      if request_attrs['service_plan_guid']
        old_plan = service_instance.service_plan
        unless old_plan.service.plan_updateable
          raise VCAP::Errors::ApiError.new_from_details('ServicePlanNotUpdateable')
        end

        new_plan = ServicePlan.find(guid: request_attrs['service_plan_guid'])
        raise VCAP::Errors::ApiError.new_from_details('InvalidRelation', 'Plan') unless new_plan
      end

      unless ['true', 'false', nil].include? params['accepts_incomplete']
        raise Errors::ApiError.new_from_details('InvalidRequest')
      end
    end

    def accepts_incomplete?(params)
      params['accepts_incomplete'] == 'true'
    end
  end
end
