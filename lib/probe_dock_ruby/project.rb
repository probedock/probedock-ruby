module ProbeDockProbe

  class Project
    attr_accessor :version, :api_id, :category, :tags, :tickets

    def initialize options = {}
      update({
        tags: [],
        tickets: []
      }.merge(options))
    end

    def update options = {}
      %i(version api_id category).each{ |attr| set_string(attr, options[attr]) if options.key?(attr) }
      %i(tags tickets).each{ |attr| set_array(attr, options[attr]) if options.key?(attr) }
    end

    def clear
      %i(api_id version category).each{ |attr| set_string(attr, nil) }
      %i(tags tickets).each{ |attr| set_array(attr, []) }
    end

    def validate!
      required = { "version" => @version, "API identifier" => @api_id }
      missing = required.inject([]){ |memo,(k,v)| v.to_s.strip.length <= 0 ? memo << k : memo }
      raise PayloadError.new("Missing project options: #{missing.join ', '}") if missing.any?
    end

    private

    def set_string attr, value
      instance_variable_set "@#{attr}", value ? value.to_s : nil
    end

    def set_array attr, value
      instance_variable_set "@#{attr}", wrap(value).compact
    end

    def wrap a
      a.kind_of?(Array) ? a : [ a ]
    end
  end
end
