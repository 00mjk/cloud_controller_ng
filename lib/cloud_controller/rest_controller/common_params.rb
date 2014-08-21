require "cgi"

module VCAP::CloudController::RestController
  class CommonParams
    def initialize(logger)
      @logger = logger
    end

    def parse(params, query_string=nil)
      @logger.debug "parse_params: #{params} #{query_string}"
      # Sinatra squshes duplicate query parms into a single entry rather
      # than an array (which we might have for q)
      res = {}
      [
        ["inline-relations-depth", Integer],
        ["page", Integer],
        ["results-per-page", Integer],
        ["q", String],
        ["order-direction", String],

      ].each do |key, klass|
        val = params[key]
        res[key.underscore.to_sym] = Object.send(klass.name, val) if val
      end

      if res[:q] && query_string && query_string.count("q=") > 1
        res[:q] = CGI.parse(query_string)["q"]
      end

      res
    end
  end
end
