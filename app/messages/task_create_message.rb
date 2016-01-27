require 'messages/base_message'

module VCAP::CloudController
  class TaskCreateMessage < BaseMessage
    ALLOWED_KEYS = [:name, :command, :environment_variables]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :environment_variables, hash: true, allow_nil: true

    def self.create(body)
      TaskCreateMessage.new(body.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
