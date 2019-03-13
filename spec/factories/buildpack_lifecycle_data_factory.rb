require 'models/runtime/buildpack_lifecycle_data_model'

FactoryBot.define do
  factory(
    :buildpack_lifecycle_data,
    aliases: [:buildpack_lifecycle_data_model],
    class: VCAP::CloudController::BuildpackLifecycleDataModel
  ) do
    buildpacks { nil }
    stack { create(:stack).name }
  end
end
