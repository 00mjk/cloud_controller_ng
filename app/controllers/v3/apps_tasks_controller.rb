require 'queries/app_fetcher'
require 'actions/task_create'
require 'messages/task_create_message'
require 'presenters/v3/task_presenter'

class AppsTasksController < ApplicationController
  def create
    FeatureFlag.raise_unless_enabled!('task_creation')
    message = TaskCreateMessage.new(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_guid = params[:guid]
    app = AppModel.where(guid: app_guid).eager(:space, space: :organization).first

    resource_not_found!(:app) unless app && can_read?(app.space.guid, app.space.organization.guid)
    unauthorized! unless can_create?(app.space.guid)

    task = TaskCreate.new.create(app, message)
    render status: :accepted, json: TaskPresenter.new.present_json(task)
  rescue TaskCreate::InvalidTask, TaskCreate::NoAssignedDroplet => e
    unprocessable!(e)
  end

  def show
    query_options = { guid: params[:task_guid] }
    if params[:app_guid].present?
      query_options[:app_id] = AppModel.select(:id).where(guid: params[:app_guid])
    end
    task = TaskModel.where(query_options).eager(:space, space: :organization).first

    resource_not_found!(:task) unless task && can_read?(task.space.guid, task.space.organization.guid)
    render status: :ok, json: TaskPresenter.new.present_json(task)
  end

  private

  def resource_not_found!(resource)
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', "#{resource.to_s.capitalize} not found")
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
    membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                               Membership::SPACE_MANAGER,
                               Membership::SPACE_AUDITOR,
                               Membership::ORG_MANAGER], space_guid, org_guid)
  end

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
end
