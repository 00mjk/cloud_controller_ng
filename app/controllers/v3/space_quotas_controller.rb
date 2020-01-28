require 'actions/space_quotas_create'
require 'messages/space_quotas_create_message'
require 'messages/space_quotas_list_message'
require 'presenters/v3/space_quota_presenter'

class SpaceQuotasController < ApplicationController
  def create
    message = VCAP::CloudController::SpaceQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)

    org = Organization.find(guid: message.organization_guid)
    unprocessable_organization!(message.organization_guid) unless org

    space_quota = SpaceQuotasCreate.new.create(message, organization: org)

    render status: :created, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      visible_space_guids: permission_queryer.readable_space_guids
    )
  rescue SpaceQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def show
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:space_quota) unless space_quota

    owning_org = Organization.first(id: space_quota.organization_id).guid
    readable_space_guids = permission_queryer.readable_space_guids

    resource_not_found!(:space_quota) unless permission_queryer.can_read_globally? ||
      permission_queryer.can_write_to_org?(owning_org) ||
      !space_quota.spaces_dataset.where(guid: readable_space_guids).empty?

    render status: :ok, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      visible_space_guids: readable_space_guids
    )
  end

  def index
    message = VCAP::CloudController::SpaceQuotasListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    # readable_org_guids_with_contents
    dataset = SpaceQuotaDefinition.where(
      # all space quotas where the org that the quota lives in is readable to the queryer
      organization: Organization.where(guid: permission_queryer.readable_org_contents_org_guids)
    ).union(
      # all space quotas where the space that the quota is applied to is readable to the queryer
      SpaceQuotaDefinition.where(spaces: Space.where(guid: permission_queryer.readable_space_guids)),
      alias: :space_quota_definitions
    )
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SpaceQuotaPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/space_quotas',
      message: message,
      extra_presenter_args: { visible_space_guids: permission_queryer.readable_space_guids },
    )
  end

  private

  def unprocessable_organization!(org_guid)
    unprocessable!("Organization with guid '#{org_guid}' does not exist, or you do not have access to it.")
  end
end
