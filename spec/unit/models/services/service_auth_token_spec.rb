require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthToken, type: :model do

    it_behaves_like "a model with an encrypted attribute" do
      let(:encrypted_attr) { :token }
    end

    it { should have_timestamp_columns }

    describe "Associations" do
      it { should have_associated :service }
    end

    describe "Validations" do
      it { should validate_presence :label }
      it { should validate_presence :provider }
      it { should validate_presence :token }
      it { should validate_uniqueness [:label, :provider] }
      it { should strip_whitespace :label }
      it { should strip_whitespace :provider }
    end

    describe "Serialization" do
      it { should export_attributes :label, :provider }
      it { should import_attributes :label, :provider, :token }
    end
  end
end
