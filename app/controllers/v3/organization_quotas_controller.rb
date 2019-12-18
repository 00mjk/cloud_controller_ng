require 'actions/organization_quotas_create'
require 'messages/organization_quotas_create_message'
require 'presenters/v3/organization_quotas_presenter'

class OrganizationQuotasController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organization_quota = OrganizationQuotasCreate.new.create(message)

    render json: Presenters::V3::OrganizationQuotasPresenter.new(organization_quota), status: :created
  rescue OrganizationQuotasCreate::Error => e
    unprocessable!(e.message)
  end
end
