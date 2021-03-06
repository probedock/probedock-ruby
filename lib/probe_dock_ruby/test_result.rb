module ProbeDockProbe
  class TestResult
    attr_reader :key, :fingerprint, :name, :category, :active, :tags, :tickets, :data, :duration, :message

    def initialize project, options = {}

      if !options[:fingerprint]
        raise Error, "The :fingerprint option is required (unique identifier for the test)"
      elsif !options[:name]
        raise Error, "The :name option is required (human-friendly identifier for the test, not necessarily unique)"
      elsif !options.key?(:passed)
        raise Error, "The :passed option is required (indicates whether the test passed or not)"
      elsif !options[:duration]
        raise Error, "The :duration options is required (indicates how long it took to run the test)"
      end

      @fingerprint = options[:fingerprint]

      @name = options[:name].to_s

      annotation = Annotation.new('')

      if @name.match(Annotation::ANNOTATION_REGEXP)
        annotation.merge!(Annotation.new(@name))
        @name = Annotation.strip_annotations(@name)
      end

      options_annotation = options[:annotation]
      options_annotation = Annotation.new(options_annotation) if options_annotation.kind_of?(String)
      annotation.merge!(options_annotation) if options_annotation

      @key = options[:key] || annotation.key
      @category = options[:category] || annotation.category || project.category
      @tags = (wrap(options[:tags]) + wrap(annotation.tags) + wrap(project.tags)).compact.collect(&:to_s).uniq
      @tickets = (wrap(options[:tickets]) + wrap(annotation.tickets) + wrap(project.tickets)).compact.collect(&:to_s).uniq

      @passed = !!options[:passed]

      if !options[:active].nil?
        @active = options[:active]
      elsif !annotation.active.nil?
        @active = annotation.active
      end

      @duration = options[:duration]
      @message = options[:message]

      @data = options[:data] || {}
      @data = @data.deep_stringify_keys if @data.respond_to? :deep_stringify_keys
    end

    def passed?
      @passed
    end

    def to_h options = {}
      {
        'f' => @fingerprint,
        'p' => @passed,
        'd' => @duration
      }.tap do |h|
        h['k'] = @key if @key
        h['m'] = @message if @message
        h['n'] = @name.length > 255 ? "#{@name[0, 252]}..." : @name
        h['c'] = @category
        h['v'] = @active unless @active.nil?
        h['g'] = @tags
        h['t'] = @tickets
        h['a'] = @data
      end
    end

    def wrap a
      a.kind_of?(Array) ? a : [ a ]
    end
  end
end
