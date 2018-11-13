module VCAP::CloudController
  module AnnotationsUpdate
    class << self
      def update(resource, annotations, annotation_klass)
        annotations ||= {}
        annotations.each do |key, value|
          key = key.to_s
          if value.nil?
            annotation_klass.find(resource_guid: resource.guid, key: key).try(:destroy)
            next
          end
          annotation = annotation_klass.find_or_create(resource_guid: resource.guid, key: key)
          annotation.update(value: value.to_s)
        end
      end
    end
  end
end
