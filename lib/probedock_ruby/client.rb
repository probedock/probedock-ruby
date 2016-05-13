require 'paint'

module ProbeDockProbe
  class Client

    def initialize config
      @config = config
      raise "A configuration is required" unless @config
    end

    def process test_run

      return fail "No server to publish results to" if !@config.server

      uid = UID.new workspace: @config.workspace
      test_run.uid = uid.load_uid

      payload_options = {}
      return false unless payload = build_payload(test_run, payload_options)

      published = if !@config.publish
        puts Paint["Probe Dock - Publishing disabled", :yellow]
        false
      elsif publish_payload payload
        true
      else
        false
      end

      save_payload payload if @config.save_payload
      print_payload payload if @config.print_payload

      puts

      published
    end

    private

    def build_payload test_run, options = {}
      begin
        test_run.to_h options
      rescue PayloadError => e
        fail e.message
      end
    end

    def fail msg, type = :error
      styles = { warning: [ :yellow ], error: [ :bold, :red ] }
      warn Paint["Probe Dock - #{msg}", *styles[type]]
      false
    end

    def print_payload payload
      puts Paint['Probe Dock - Printing payload...', :yellow]
      begin
        puts JSON.pretty_generate(payload)
      rescue
        puts payload.inspect
      end
    end

    def save_payload payload

      missing = { "workspace" => @config.workspace, "server" => @config.server }.inject([]){ |memo,(k,v)| !v ? memo << k : memo }
      return fail "Cannot save payload without a #{missing.join ' and '}" if missing.any?

      FileUtils.mkdir_p File.dirname(payload_file)
      File.open(payload_file, 'w'){ |f| f.write Oj.dump(payload, mode: :strict) }
    end

    def payload_file
      @payload_file ||= File.join(@config.workspace, 'rspec', 'servers', @config.server.name, 'payload.json')
    end

    def publish_payload payload

      puts Paint["Probe Dock - Sending payload to #{@config.server.api_url}...", :magenta]

      begin
        if @config.local_mode
          puts Paint['Probe Dock - LOCAL MODE: not actually sending payload.', :yellow]
        else
          @config.server.upload payload
        end
        puts Paint["Probe Dock - Done!", :green]
        true
      rescue Server::Error => e
        warn Paint["Probe Dock - Upload failed!", :red, :bold]
        warn Paint["Probe Dock - #{e.message}", :red, :bold]
        if e.response
          warn Paint["Probe Dock - Dumping response body...", :red, :bold]
          warn e.response.body
        end
        false
      end
    end
  end
end
