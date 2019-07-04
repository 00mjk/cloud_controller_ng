require 'messages/base_message'
require 'utils/hash_utils'

module VCAP::CloudController
  class ServiceBrokerCreateMessage < BaseMessage
    register_allowed_keys [:name, :url, :credentials, :relationships]
    ALLOWED_CREDENTIAL_TYPES = ['basic'].freeze

    def self.relationships_requested?
      @relationships_requested ||= proc { |a| a.requested?(:relationships) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with RelationshipValidator, if: relationships_requested?

    validates :name, string: true
    validates :url, string: true

    validates :credentials, hash: true
    validates_inclusion_of :credentials_type, in: ALLOWED_CREDENTIAL_TYPES,
      message: "credentials.type must be one of #{ALLOWED_CREDENTIAL_TYPES}"
    validate :validate_credentials
    validate :validate_credentials_data
    validate :validate_url
    validate :validate_name

    def relationships_message
      @relationships_message ||= Relationships.new(relationships&.deep_symbolize_keys)
    end

    def credentials_data_hash
      HashUtils.dig(credentials, :data)
    end

    def credentials_message
      @credentials_message ||= CredentialsMessage.new(credentials)
    end

    def credentials_data
      @credentials_data ||= BasicCredentialsMessage.new(credentials_data_hash)
    end

    def validate_credentials
      unless credentials_message.valid?
        errors.add(:credentials, credentials_message.errors[:base])
      end
    end

    def credentials_type
      HashUtils.dig(credentials, :type)
    end

    def validate_credentials_data
      unless credentials_data_hash.is_a?(Hash)
        errors.add(:credentials_data, 'must be a hash')
      end
      unless credentials_data.valid?
        errors.add(
          :credentials_data,
          "Field(s) #{credentials_data.errors.keys.map(&:to_s)} must be valid: #{credentials_data.errors.full_messages}"
        )
      end
    end

    def validate_url
      if URI::DEFAULT_PARSER.make_regexp(['https', 'http']).match?(url.to_s)
        errors.add(:url, 'must not contain credentials') if URI(url).user
      else
        errors.add(:url, 'must be a valid url')
      end
    end

    def validate_name
      if name == ''
        errors.add(:name, 'must not be empty string')
      end
    end

    delegate :space_guid, to: :relationships_message

    class CredentialsMessage < BaseMessage
      register_allowed_keys [:type, :data]

      validates_with NoAdditionalKeysValidator
    end

    class BasicCredentialsMessage < BaseMessage
      register_allowed_keys [:username, :password]

      validates_with NoAdditionalKeysValidator

      validates :username, string: true
      validates :password, string: true
    end

    class Relationships < BaseMessage
      register_allowed_keys [:space]

      validates_with NoAdditionalKeysValidator

      validates :space, presence: true, allow_nil: false, to_one_relationship: true

      def space_guid
        HashUtils.dig(space, :data, :guid)
      end
    end
  end
end
