class Capture

  module Helpers

    def capture *args, &block
      Capture.capture *args, &block
    end
  end

  attr_reader :result, :stdout, :stderr

  def initialize options = {}
    @result, @stdout, @stderr = options[:result], options[:stdout], options[:stderr]
  end

  def output join = nil
    "#{@stdout}#{join}#{@stderr}"
  end

  def self.capture options = {}, &block
    result = nil
    stdout, stderr = StringIO.new, StringIO.new
    $stdout, $stderr = stdout, stderr

    begin
      result = block.call if block_given?
    rescue StandardError => e
      STDOUT.puts $stdout.string unless options[:silence_errors]
      STDERR.puts $stderr.string unless options[:silence_errors]
      $stdout, $stderr = STDOUT, STDERR
      raise e
    end

    $stdout, $stderr = STDOUT, STDERR
    new result: result, stdout: stdout.string, stderr: stderr.string
  end
end
