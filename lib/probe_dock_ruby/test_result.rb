module ProbeDockProbe
  class TestResult
    attr_reader :key, :fingerprint, :name, :category, :tags, :tickets, :data, :duration, :message

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

      @key = options[:key]
      @fingerprint = options[:fingerprint]
      @name = options[:name]

      @category = options[:category] || project.category
      @tags = (wrap(options[:tags]) + wrap(project.tags)).compact.collect(&:to_s).uniq
      @tickets = (wrap(options[:tickets]) + wrap(project.tickets)).compact.collect(&:to_s).uniq

      @grouped = !!options[:grouped]
      @passed = !!options[:passed]
      @duration = options[:duration]
      @message = options[:message]

      @data = options[:data] || {}
    end

    def passed?
      @passed
    end

    def grouped?
      @grouped
    end

    def update options = {}

      @passed &&= options[:passed]
      @duration += options[:duration]
      @message = [ @message, options[:message] ].compact.join("\n\n") if options[:message]

      @category = options[:category] if options[:category]
      @tags = (@tags + wrap(options[:tags]).compact.collect(&:to_s)).uniq if options[:tags]
      @tickets = (@tickets + wrap(options[:tickets]).compact.collect(&:to_s)).uniq if options[:tickets]
    end

    def to_h options = {}
      {
        'f' => @fingerprint,
        'p' => @passed,
        'd' => @duration
      }.tap do |h|
        h['k'] = @key if @key
        h['m'] = @message if @message
        h['n'] = @name
        h['c'] = @category
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
