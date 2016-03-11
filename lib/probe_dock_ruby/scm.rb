require 'ostruct'

module ProbeDockProbe
  class Scm
    attr_accessor :name, :version, :dirty, :remote

    def initialize
      clear
    end

    def update options = {}
      %i(name version).each do |key|
        instance_variable_set("@#{key}", options[key] ? options[key].to_s : nil) if options.key?(key)
      end

      @dirty = !!options[:dirty] if options.key?(:dirty)

      remote_options = options[:remote].kind_of?(Hash) ? options[:remote] : {}
      @remote[:name] = remote_options[:name] ? remote_options[:name].to_s : nil if remote_options.key?(:name)
      @remote[:ahead] = remote_options[:ahead] ? remote_options[:ahead].to_i : nil if remote_options.key?(:ahead)
      @remote[:behind] = remote_options[:behind] ? remote_options[:behind].to_i : nil if remote_options.key?(:behind)

      url = @remote[:url]
      remote_url_options = remote_options[:url].kind_of?(Hash) ? remote_options[:url] : {}
      url[:fetch] = remote_url_options[:fetch] ? remote_url_options[:fetch].to_s : nil if remote_url_options.key?(:fetch)
      url[:push] = remote_url_options[:push] ? remote_url_options[:push].to_s : nil if remote_url_options.key?(:push)
    end

    def clear
      %i(name version dirty).each{ |attr| instance_variable_set("@#{attr}", nil) }
      @remote = OpenStruct.new({
        url: OpenStruct.new
      })
    end
  end
end
