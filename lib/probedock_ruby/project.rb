require File.join(File.dirname(__FILE__), 'configurable.rb')

module ProbeDockProbe
  class Project
    include Configurable

    configurable({
      api_id: :string,
      version: :string,
      category: :string,
      tags: :string_array,
      tickets: :string_array
    })

    def validate!
      required = { "version" => @version, "API identifier" => @api_id }
      missing = required.inject([]){ |memo,(k,v)| v.to_s.strip.length <= 0 ? memo << k : memo }
      raise PayloadError.new("Missing project options: #{missing.join ', '}") if missing.any?
    end
  end
end
