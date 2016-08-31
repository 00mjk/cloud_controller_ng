module VCAP::CloudController
  class IsolationSegmentModel < Sequel::Model(:isolation_segments)
    include Serializer
    ISOLATION_SEGMENT_MODEL_REGEX = /\A[[:print:]]+\Z/

    one_to_many :spaces,
      key: :isolation_segment_guid,
      primary_key: :guid

    def validate
      validates_format ISOLATION_SEGMENT_MODEL_REGEX, :name, message: Sequel.lit('isolation segment names can only contain non-blank unicode characters')

      validates_unique [:name], message: Sequel.lit('isolation segment names are case insensitive and must be unique')
    end
  end
end
