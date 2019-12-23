require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class OrganizationQuotasPresenter < BasePresenter
    def to_hash
      {
        guid: organization_quota.guid,
        created_at: organization_quota.created_at,
        updated_at: organization_quota.updated_at,
        name: organization_quota.name,
        relationships: {
          organizations: {
            data: organization_quota.organizations.map { |organization| { guid: organization.guid } }
          }
        },
        apps: {
          total_memory_in_mb: convert_unlimited_to_nil(organization_quota.memory_limit),
          per_process_memory_in_mb: convert_unlimited_to_nil(organization_quota.instance_memory_limit),
          total_instances: convert_unlimited_to_nil(organization_quota.app_instance_limit),
          per_app_tasks: convert_unlimited_to_nil(organization_quota.app_task_limit),
        },
        links: build_links,
      }
    end

    private

    def organization_quota
      @resource
    end

    def convert_unlimited_to_nil(value)
      value == -1 ? nil : value
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: { href: url_builder.build_url(path: "/v3/organization_quotas/#{organization_quota.guid}") },
      }
    end
  end
end
