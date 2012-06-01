# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  # Serialize objects according in the format required by the vcap
  # rest api.
  #
  # TODO: migrate this to be like messages and routes in that
  # it is included and mixed in rather than having the controller
  # passed into it?
  module ObjectSerialization
    PRETTY_DEFAULT = true

    # Render an object to json, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # encoded.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @option opts [Boolean] :pretty Controlls pretty formating of the encoded
    # json.  Defaults to true.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    #
    # @return [String] Json encoding of the object.
    def self.render_json(controller, obj, opts = {})
      opts[:pretty] = PRETTY_DEFAULT unless opts.has_key?(:pretty)
      Yajl::Encoder.encode(to_hash(controller, obj, opts),
                           :pretty => opts[:pretty])
    end

    # Render an object as a hash, using export and security properties
    # set by its controller.
    #
    # @param [RestController] controller Controller for the object being
    # serialized.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @param [Sequel::Model] obj Object to encode.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    #
    # @param [Integer] depth The current recursion depth.
    #
    # @param [Array] parents The recursion stack of classes that
    # we have expanded through.
    #
    # @return [Hash] Hash encoding of the object.
    def self.to_hash(controller, obj, opts, depth=0, parents=[])
      rel_hash = relations_hash(controller, obj, opts, depth, parents)

      # TODO: this needs to do a read authz check.
      entity_hash = obj.to_hash.merge(rel_hash)

      metadata_hash = {
        "id"  => obj.id,
        "url" => controller.url_for_id(obj.id),
        "created_at" => obj.created_at,
        "updated_at" => obj.updated_at
      }

      { "metadata" => metadata_hash, "entity" => entity_hash }
    end

    private

    def self.relations_hash(controller, obj, opts, depth, parents)
      target_depth = opts[:inline_relations_depth] || 0
      max_inline = opts[:max_inline] || 50
      res = {}

      parents.push(controller)

      controller.to_many_relationships.each do |name, attr|
        other_controller = VCAP::CloudController.controller_from_name(name)
        q_key = "#{controller.class_basename.underscore}_id"
        res["#{name}_url"] = "/v2/#{name}?q=#{q_key}:#{obj.id}"

        others = obj.send(name)

        # TODO: replace depth with parents.size
        if (others.count <= max_inline &&
            depth < target_depth && !parents.include?(other_controller))
          res[name.to_s] = others.map do |other|
            other_controller = VCAP::CloudController.controller_from_model(other)
            to_hash(other_controller, other, opts, depth + 1, parents)
          end
        end
      end

      controller.to_one_relationships.each do |name, attr|
        other_controller = VCAP::CloudController.controller_from_name(name)
        other_id = obj.send("#{name}_id")
        res["#{name}_url"] = "/v2/#{name.to_s.pluralize}/#{other_id}"
        if depth < target_depth && !parents.include?(other_controller)
          other = obj.send(name)
          other_controller = VCAP::CloudController.controller_from_model(other)
          res[name.to_s] = to_hash(other_controller, other,
                                   opts, depth + 1, parents)
        end
      end

      parents.pop
      res
    end
  end
end
