require 'messages/base_message'

module VCAP::CloudController
  class SpaceUpdateIsolationSegmentMessage < BaseMessage
    ALLOWED_KEYS = [:data].freeze

    attr_accessor(*ALLOWED_KEYS)

    def self.data_requested?
      @data_requested ||= proc { |a| a.requested?(:data) }
    end

    validates_with NoAdditionalKeysValidator
    validates :data, presence: true, hash: true, allow_nil: true
    validate :data_content, if: data_requested?

    def isolation_segment_guid
      return data['guid'] if data
      nil
    end

    def data_content
      return if data.nil?
      errors.add(:data, 'can only accept one key') unless data.keys.length == 1
      errors.add(:data, "can only accept key 'guid'") unless data.keys.include?('guid')
      errors.add(:data, "#{data['guid']} must be a string") if data['guid'] && !data['guid'].is_a?(String)
    end

    def self.create_from_http_request(body)
      SpaceUpdateIsolationSegmentMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
