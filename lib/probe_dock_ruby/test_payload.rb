require 'fileutils'
require 'digest/sha2'

module ProbeDockProbe

  class TestPayload

    class Error < ProbeDockProbe::Error; end

    def initialize run
      @run = run
    end

    def to_h options = {}
      @run.to_h options
    end
  end
end
