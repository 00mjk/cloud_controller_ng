shared_examples "model instance" do |opts|
  ([:unique_attributes, :stripped_string_attributes,
    :sensitive_attributes, :extra_json_attributes, :disable_examples]).each do |k|
    opts[k] ||= []
    opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
  end

  unless opts[:disable_examples].include? :creation
    describe "creation" do
      include_examples "creation with all required attributes"
      include_examples "creation of unique attributes", opts
    end
  end

  unless opts[:disable_examples].include? :updates
    describe "updates" do
      include_examples "timestamps", opts
    end
  end

  unless opts[:disable_examples].include? :attribute_normalization
    describe "attribute normalization" do
      include_examples "attribute normalization", opts
    end
  end

  unless opts[:disable_examples].include? :seralization
    describe "serialization" do
      include_examples "serialization", opts
    end
  end

  unless opts[:disable_examples].include? :deserialization
    describe "deserialization" do
      include_examples "deserialization", opts
    end
  end

  unless opts[:disable_examples].include? :deletion
    describe "deletion" do
      let(:obj) { described_class.make }

      it "should succeed" do
        obj.destroy(savepoint: true)
      end
    end
  end
end

