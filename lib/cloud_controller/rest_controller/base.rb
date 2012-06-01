# Copyright (c) 2009-2012 VMware, Inr.

module VCAP::CloudController::RestController

  # The base class for all api endpoints.
  class Base
    ROUTE_PREFIX = "/v2"

    include VCAP::CloudController
    include VCAP::CloudController::Errors
    include VCAP::RestAPI
    include PermissionManager
    include Messages
    include Routes

    # Tell the PermissionManager the types of operations that can be performed.
    define_permitted_operation :create
    define_permitted_operation :read
    define_permitted_operation :update
    define_permitted_operation :delete
    define_permitted_operation :enumerate

    # Create a new rest api endpoint.
    #
    # @param [Models::User] user The user peforming the rest request.  It may
    # be nil.
    #
    # @param [VCAP::Logger] logger The logger to use during the request.
    #
    # @param [Sinatra::Request] request The full sinatra request object.
    def initialize(user, logger, request)
      @user    = user
      @logger  = logger
      @opts    = parse_params(request.params)
    end

    # Parses and sanitizes query parameters from the sinatra request.
    #
    # @return [Hash] the parsed parameter hash
    def parse_params(params)
      { :q => params["q"] }
    end

    # Main entry point for the rest routes.  Acts as the final location
    # for catching any unhandled sequel and db exceptions.  By calling
    # translate_and_log_exception, they will get logged so that we can
    # address them and will get converted to a generic invalid request
    # so that they can be investigated and have more accurate error
    # reporting added.
    #
    # @param [Symbol] method The method to dispatch to
    #
    # @param [Array] args The arguments to the method beign disptched to.
    #
    # @return [Object] Returns an array of [http response code, Header hash,
    # body string], or just a body string.
    def dispatch(method, *args)
      send(method, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_and_log_exception(@logger, e)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(@logger, e)
    end

    # Create operation
    #
    # @param [IO] json An IO object that when read will return the json
    # serialized request.
    def create(json)
      validate_class_access(:create)
      attributes = Yajl::Parser.new.parse(json)
      raise InvalidRequest unless attributes
      obj = model.create_from_hash(attributes)
      [HTTP::CREATED,
       { "Location" => "#{self.class.path}/#{obj.id}" },
      ObjectSerialization.render_json(self.class, obj)]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, attributes)
    end

    # Read operation
    #
    # @param [String] id The GUID of the object to read.
    def read(id)
      obj = find_id_and_validate_access(:read, id)
      ObjectSerialization.render_json(self.class, obj)
    end

    # Update operation
    #
    # @param [String] id The GUID of the object to update.
    #
    # @param [IO] json An IO object that when read will return the json
    # serialized request.
    def update(id, json)
      obj = find_id_and_validate_access(:update, id)
      attributes = Yajl::Parser.new.parse(json)
      obj.update_from_hash(attributes)
      obj.save
      [HTTP::CREATED, ObjectSerialization.render_json(self.class, obj)]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, attributes)
    end

    # Delete operation
    #
    # @param [String] id The GUID of the object to delete.
    def delete(id)
      obj = find_id_and_validate_access(:delete, id)
      obj.delete
      [HTTP::NO_CONTENT, nil]
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, attributes)
    end

    # Enumerate operation
    def enumerate
      # TODO: filter the ds by what the user can see
      ds = Query.dataset_from_query_params(model,
                                           self.class.query_parameters, @opts)
      resources = []
      ds.all.each do |m|
        resources << ObjectSerialization.to_hash(self.class, m)
      end

      res = {}
      res[:total_results] = ds.count
      res[:prev_url] = nil
      res[:next_url] = nil
      res[:resources] = resources

      Yajl::Encoder.encode(res, :pretty => true)
    end

    # Validates if the current user has rights to perform the given operation
    # on this class of object. Rasies an auth error if not.
    #
    # @param [Symbol] op The type of operation to check for access
    def validate_class_access(op)
      validate_access(op, model, @user)
    end

    # Find an object and validate that the current user has rights to
    # perform the given operation on that instance.
    #
    # Raises an exception if the object can't be found or if the current user
    # doesn't have access to it.
    #
    # @param [Symbol] op The type of operation to check for access
    #
    # @param [String] id The GUID of the object to find.
    #
    # @return [Sequel::Model] The sequel model for the object, only if
    # the use has access.
    def find_id_and_validate_access(op, id)
      obj = model.find(:id => id)
      if obj
        validate_access(op, obj, @user)
      else
        raise self.class.not_found_exception.new(id) if obj.nil?
      end
      obj
    end

    # Find an object and validate that the given user has rights
    # to access the instance.
    #
    # Raises an exception if the user does not have rights to peform
    # the operation on the object.
    #
    # @param [Symbol] op The type of operation to check for access
    #
    # @param [Object] obj The object for which to validate access.
    #
    # @param [Models::User] user The user for which to validate access.
    def validate_access(op, obj, user)
      user_perms = Permissions.permissions_for(obj, user)
      unless self.class.op_allowed_by?(op, user_perms)
        raise NotAuthenticated unless user
        raise NotAuthorized
      end
    end

    # The model associated with this api endpoint.
    #
    # @return [Sequel::Model] The model associated with this api endpoint.
    def model
      self.class.model
    end

    class << self
      include VCAP::CloudController

      attr_accessor :attributes
      attr_accessor :to_many_relationships
      attr_accessor :to_one_relationships

      # basename of the class
      #
      # @return [String] basename of the class
      def class_basename
        self.name.split("::").last
      end

      # path
      #
      # @return [String] The path/route to the collection associated with
      # the class.
      def path
        "#{ROUTE_PREFIX}/#{class_basename.underscore.pluralize}"
      end

      # path_id
      #
      # @return [String] The path/route to an instance of this class.
      def path_id
        "#{path}/:id"
      end

      # Return the url for a specfic id
      #
      # @return [String] The url for a specific instance of this class.
      def url_for_id(id)
        "#{path}/#{id}"
      end

      # Model associated with this rest/api endpoint
      #
      # @param [String] name The base name of the model class.
      #
      # @return [Sequel::Model] The class of the model associated with
      # this rest endpoint.
      def model(name = model_class_name)
        Models.const_get(name)
      end

      # Model class name associated with this rest/api endpoint.
      #
      # @return [String] The class name of the model associated with
      # this rest endpoint.
      def model_class_name
        class_basename
      end

      # Model class name associated with this rest/api endpoint.
      #
      # @return [String] The class name of the model associated with
      def not_found_exception_name
        "#{model_class_name}NotFound"
      end

      # Lookup the not-found exception for this rest/api endpoint.
      #
      # @return [Exception] The vcap not-found exception for this
      # rest/api endpoint.
      def not_found_exception
        Errors.const_get(not_found_exception_name)
      end

      # Get and set the allowed query paramaeters (sent via the q http
      # query parmameter) for this rest/api endpoint.
      #
      # @param [Array] args One or more attributes that can be used
      # as query parameters.
      #
      # @return [Set] If called with no arguments, returns the list
      # of query parameters.
      def query_parameters(*args)
        if args.empty?
          @query_parameters ||= Set.new
        else
          @query_parameters ||= Set.new
          @query_parameters |= Set.new(args.map { |a| a.to_s })
        end
      end

      # Start the DSL for defining attributes.  This is used inside
      # the api controller classes.
      def define_attributes(&blk)
        k = Class.new do
          include ControllerDSL
        end

        k.new(self).instance_eval(&blk)
      end

      # Start the DSL for defining attributes.  This is used inside
      # the api controller classes.
      #
      def translate_and_log_exception(logger, e)
        msg = ["exception not translated: #{e.class} - #{e.message}"]
        msg[0] = msg[0] + ":"
        msg.concat(e.backtrace).join("\\n")
        logger.warn(msg.join("\\n"))
        Errors::InvalidRequest
      end
    end
  end
end
