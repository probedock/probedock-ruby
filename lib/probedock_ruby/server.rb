require 'oj'
require 'httparty'
require File.join(File.dirname(__FILE__), 'configurable.rb')

module ProbeDockProbe
  class Server
    include Configurable

    class Error < ProbeDockProbe::Error
      attr_reader :response

      def initialize msg, response = nil
        super msg
        @response = response
      end
    end

    configurable({
      api_url: :string,
      api_token: :string,
      project_api_id: :string
    })

    attr_reader :name

    def initialize options = {}
      super options
      @name = options[:name].to_s.strip if options[:name]
    end

    def upload payload
      validate!

      body = Oj.dump payload, mode: :strict
      res = HTTParty.post payload_uri, body: body, headers: payload_headers

      if res.code != 202
        raise Error.new("Expected HTTP 202 Accepted when submitting payload, got #{res.code}", res)
      end
    end

    private

    def validate!
      required = { "name" => @name, "apiUrl" => @api_url, "apiToken" => @api_token }
      missing = required.inject([]){ |memo,(k,v)| v.to_s.strip.length <= 0 ? memo << k : memo }
      raise Error.new("Server #{@name} is missing the following options: #{missing.join ', '}") if missing.any?
    end

    def payload_headers
      { 'Authorization' => "Bearer #{@api_token}", 'Content-Type' => 'application/vnd.probedock.payload.v1+json' }
    end

    def payload_uri
      "#{@api_url}/publish"
    end
  end
end
