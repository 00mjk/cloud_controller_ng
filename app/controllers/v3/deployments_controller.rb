require 'presenters/v3/deployment_presenter'

class DeploymentsController < ApplicationController
  def create
    app_guid = HashUtils.dig(params[:body], :relationships, :app, :data, :guid)
    app = AppModel.find(guid: app_guid)
    unprocessable!('Unable to use app. Ensure that the app exists and you have access to it.') unless app && can_write?(app.space.guid)
    deployment = DeploymentModel.create(app: app, state: DeploymentModel::DEPLOYING_STATE)

    response = Presenters::V3::DeploymentPresenter.new(deployment)

    render status: :created, json: response.to_json
  end

  def show
    deployment = DeploymentModel.find(guid: params[:guid])

    resource_not_found!(:deployment) unless deployment &&
      can_read?(deployment.app.space.guid, deployment.app.space.organization.guid)

    render status: :ok, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end
end
