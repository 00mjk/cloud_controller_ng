require 'messages/list_message'

module VCAP::CloudController
  class EventsListMessage < ListMessage
    class CreatedAtValidator < ActiveModel::Validator
      def validate(record)
        if record.requested?(:created_ats)
          if record.created_ats.is_a?(Array)
            record.created_ats.each do |timestamp|
              opinionated_iso_8601(timestamp, record)
            end
          else
            unless record.created_ats.is_a?(Hash)
              record.errors[:created_ats] << 'relational operator and timestamp must be specified'
              return
            end

            valid_relational_operators = [
              Event::LESS_THAN_COMPARATOR,
              Event::GREATER_THAN_COMPARATOR,
              Event::LESS_THAN_OR_EQUAL_COMPARATOR,
              Event::GREATER_THAN_OR_EQUAL_COMPARATOR,
            ]

            record.created_ats.each do |relational_operator, timestamp|
              unless valid_relational_operators.include?(relational_operator)
                record.errors[:created_ats] << "Invalid relational operator: '#{relational_operator}'"
              end

              if timestamp.to_s.include?(',')
                record.errors[:created_ats] << 'only accepts one value when using a relational operator'
                next
              end

              opinionated_iso_8601(timestamp, record)
            end
          end
        end
      end

      private

      def opinionated_iso_8601(timestamp, record)
        if timestamp !~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\Z/
          record.errors[:created_ats] << "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'"
        end
      end
    end

    register_allowed_keys [
      :types,
      :target_guids,
      :space_guids,
      :organization_guids,
      :created_ats
    ]

    validates_with NoAdditionalParamsValidator
    validates_with CreatedAtValidator

    validates :types, array: true, allow_nil: true
    validates :target_guids, array: true, allow_nil: true
    validates :space_guids, array: true, allow_nil: true
    validates :organization_guids, array: true, allow_nil: true

    def self.from_params(params)
      super(params, %w(types target_guids space_guids organization_guids created_ats))
    end
  end
end
