module ProbeDockProbe
  class TestRun
    attr_reader :results, :project
    attr_accessor :duration, :uid

    def initialize project
      @results = []
      @project = project
    end

    def add_result options = {}
      @results << TestResult.new(@project, options)
    end

    def to_h options = {}
      validate!

      {
        'projectId' => @project.api_id,
        'version' => @project.version,
        'duration' => @duration,
        'results' => @results.collect{ |r| r.to_h options }
      }.tap do |h|
        h['reports'] = [ { 'uid' => @uid } ] if @uid
      end
    end

    private

    def validate!
      # TODO: validate duration
      # TODO: log information about duplicate keys (if any)
      raise PayloadError.new("Missing project") if !@project
      @project.validate!
    end
  end
end
