require 'yaml'

module ProbeDockProbe
  class Config
    # TODO: add silent/verbose option(s)
    class Error < ProbeDockProbe::Error; end
    attr_writer :publish, :local_mode, :print_payload, :save_payload
    attr_reader :project, :server, :scm, :workspace, :load_warnings

    def initialize
      @servers = []
      @server = Server.new
      @project = Project.new
      @scm = Scm.new
      @publish, @local_mode, @print_payload, @save_payload = false, false, false, false
      @load_warnings = []
    end

    def workspace= dir
      @workspace = dir ? File.expand_path(dir) : nil
    end

    def servers
      @servers.dup
    end

    %w(publish local_mode print_payload save_payload).each do |name|
      define_method("#{name}?"){ instance_variable_get("@#{name}") }
    end

    def client_options
      {
        publish: @publish,
        local_mode: @local_mode,
        workspace: @workspace,
        print_payload: @print_payload,
        save_payload: @save_payload
      }.select{ |k,v| !v.nil? }
    end

    def load!

      @server.clear
      @servers.clear

      @load_warnings = []
      config = load_config_files

      @publish = parse_env_flag :publish, config.fetch(:publish, true)
      @server_name = parse_env_option(:server) || config[:server]
      @local_mode = parse_env_flag(:local) || !!config[:local]

      self.workspace = parse_env_option(:workspace) || config[:workspace]
      @print_payload = parse_env_flag :print_payload, !!config[:payload][:print]
      @save_payload = parse_env_flag :save_payload, !!config[:payload][:save]

      build_servers! config

      project_options = config[:project]
      project_options.merge! api_id: @server.project_api_id if @server and @server.project_api_id
      @project.update project_options

      scm_options = config[:scm]
      add_scm_env_options! scm_options
      @scm.update scm_options

      yield self if block_given?

      check!
      @load_warnings.each{ |w| warn Paint["Probe Dock - #{w}", :yellow] }

      self
    end

    private

    def check!

      configs = [ home_config_file, working_config_file ]
      actual_configs = configs.select{ |f| File.exists? f }

      if actual_configs.empty?
        @load_warnings << %|No config file found, looking for:\n     #{configs.join "\n     "}|
      end

      if @servers.length == 1 && @server.empty?
        @load_warnings << "No server defined"
      elsif @server.empty? && !@server_name
        @load_warnings << "No server name given"
      elsif @server.empty? && @server_name
        @load_warnings << "Unknown server #{@server_name}"
      end
    end

    def build_servers! config

      default_server_options = { project_api_id: config[:project][:api_id] }
      server_options = config[:servers].inject({}) do |memo,(name, options)|
        memo[name] = {}.merge(options).merge(name: name)
        memo
      end

      name = @server_name.to_s.strip

      @servers = server_options.values.collect do |options|
        Server.new options
      end

      if @server_name && server = @servers.find{ |server| server.name == name }
        @server = server
      else
        @servers << @server
      end

      if @server
        {
          api_url: parse_env_option(:server_api_url),
          api_token: parse_env_option(:server_api_token),
          project_api_id: parse_env_option(:server_project_api_id)
        }.reject{ |k,v| v.nil? }.each do |k,v|
          @server.send("#{k}=", v)
        end
      end
    end

    def load_config_files

      configs = [ home_config_file, working_config_file ]
      actual_configs = configs.select{ |f| File.exists? f }
      return { servers: [], payload: {}, project: {}, scm: { remote: { url: {} } } } if actual_configs.empty?

      actual_configs.collect!{ |f| YAML.load_file f }

      actual_configs.inject({ servers: {} }) do |memo,yml|
        memo.merge! parse_general_options(yml)

        if yml['servers'].kind_of? Hash
          yml['servers'].each_pair do |k,v|
            if v.kind_of? Hash
              memo[:servers][k] = (memo[:servers][k] || {}).merge(parse_server_options(v))
            end
          end
        end

        memo[:payload] = (memo[:payload] || {}).merge parse_payload_options(yml['payload'])
        memo[:project] = (memo[:project] || {}).merge parse_project_options(yml['project'])
        memo[:scm] = (memo[:scm] || {}).merge(parse_scm_options(yml['scm']))

        memo
      end
    end

    def home_config_file
      File.join File.expand_path('~'), '.probedock', 'config.yml'
    end

    def working_config_file
      File.expand_path parse_env_option(:config) || 'probedock.yml', Dir.pwd
    end

    def parse_env_option name

      var = "PROBEDOCK_#{name.to_s.upcase}"
      return ENV[var] if ENV.key? var

      old_var = "PROBE_DOCK_#{name.to_s.upcase}"
      ENV.key?(old_var) ? ENV[old_var] : nil
    end

    def parse_env_flag name, default = false
      val = parse_env_option name
      val ? !!val.to_s.strip.match(/\A(1|y|yes|t|true)\Z/i) : default
    end

    def parse_env_integer name, default = nil
      val = parse_env_option name
      val ? val.to_i : default
    end

    def parse_general_options h
      parse_options h, %w(publish server local workspace)
    end

    def parse_server_options h
      parse_options h, %w(name apiUrl apiToken projectApiId)
    end

    def parse_payload_options h
      parse_options h, %w(save print)
    end

    def parse_project_options h
      parse_options h, %w(version apiId category tags tickets)
    end

    def parse_scm_options h
      parse_options(h, %w(name version dirty)).tap do |options|
        scm_h = h.kind_of?(Hash) ? h : {}
        options[:remote] = parse_options(scm_h['remote'], %w(name url ahead behind)).tap do |remote_options|
          remote_h = scm_h['remote'].kind_of?(Hash) ? scm_h['remote'] : {}
          remote_options[:url] = parse_options(remote_h['url'], %w(fetch push))
        end
      end
    end

    def add_scm_env_options! options
      options.merge!({
        name: parse_env_option(:scm_name),
        version: parse_env_option(:scm_version),
        dirty: parse_env_flag(:scm_dirty, nil),
      }.reject{ |k,v| v.nil? })

      options[:remote].merge!({
        name: parse_env_option(:scm_remote_name),
        ahead: parse_env_integer(:scm_remote_ahead),
        behind: parse_env_integer(:scm_remote_behind)
      }.reject{ |k,v| v.nil? })

      options[:remote][:url].merge!({
        fetch: parse_env_option(:scm_remote_url_fetch),
        push: parse_env_option(:scm_remote_url_push)
      }.reject{ |k,v| v.nil? })
    end

    def parse_options h, keys
      return {} unless h.kind_of? Hash
      keys.inject({}){ |memo,k| memo[k.gsub(/(.)([A-Z])/, '\1_\2').downcase.to_sym] = h[k] if h.key?(k); memo }
    end
  end
end
