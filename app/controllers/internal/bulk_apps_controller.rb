require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  class BulkAppsController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise CloudController::Errors::NotAuthenticated
      end
    end

    get '/internal/bulk/apps', :bulk_apps
    def bulk_apps
      batch_size = Integer(params.fetch('batch_size'))
      bulk_token = MultiJson.load(params.fetch('token'))
      last_id = Integer(bulk_token['id'] || 0)

      if params['format'] == 'fingerprint'
        bulk_fingerprint_format(batch_size, last_id)
      else
        bulk_desire_app_format(batch_size, last_id)
      end
    rescue IndexError => e
      raise ApiError.new_from_details('BadQueryParameter', e.message)
    end

    post '/internal/bulk/apps', :filtered_bulk_apps
    def filtered_bulk_apps
      raise ApiError.new_from_details('MessageParseError', 'Missing request body') if body.length == 0
      payload = MultiJson.load(body)

      processes = runners.processes_from_diego_process_guids(payload)
      messages = processes.map { |process| runners.runner_for_process(process).desire_app_message }

      MultiJson.dump(messages)
    rescue MultiJson::ParseError => e
      raise ApiError.new_from_details('MessageParseError', e.message)
    end

    private

    def bulk_desire_app_format(batch_size, last_id)
      processes = runners.diego_processes(batch_size, last_id)
      messages = processes.map { |process| runners.runner_for_process(process).desire_app_message }
      id_for_next_token = processes.empty? ? nil : processes.last.id

      MultiJson.dump(
        apps: messages,
        token: { 'id' => id_for_next_token }
      )
    end

    def bulk_fingerprint_format(batch_size, last_id)
      id_for_next_token = nil
      messages = runners.diego_apps_cache_data(batch_size, last_id).map do |id, guid, version, updated|
        id_for_next_token = id
        { 'process_guid' => Diego::ProcessGuid.from(guid, version), 'etag' => updated.to_f.to_s }
      end

      MultiJson.dump(
        fingerprints: messages,
        token: { 'id' => id_for_next_token }
      )
    end

    def runners
      dependency_locator = ::CloudController::DependencyLocator.instance
      @runners ||= dependency_locator.runners
    end
  end
end
