require 'yaml'
require File.join(File.dirname(__FILE__), 'configurable.rb')

module ProbeDockProbe
  class Config
    class Error < ProbeDockProbe::Error; end

    # TODO: add silent/verbose option(s)
    attr_accessor :publish, :local_mode, :print_payload, :save_payload
    attr_reader :project, :server, :scm, :workspace, :load_warnings

    def initialize
      initialize_servers
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

    # Clears all configuration and reloads it from configuration files and environment variables.
    def load! &block

      initialize_servers
      @project.clear
      @scm.clear
      @load_warnings = []

      file_configs = all_config_files.select{ |f| File.exists?(f) }.collect{ |f| load_config_file(f) }
      config = merge_configs(*file_configs) || empty_config

      env_config = load_env_config(config)
      config = merge_config(config, env_config)

      apply_configuration!(config, &block)

      validate
      @load_warnings.each{ |w| warn Paint["Probe Dock - #{w}", :yellow] }

      self
    end

    private

    def apply_configuration! config

      @publish = !!config.fetch(:publish, true)
      @local_mode = !!config[:local]

      self.workspace = config[:workspace]
      @print_payload = !!config[:payload][:print]
      @save_payload = !!config[:payload][:save]

      @server_name = config[:server]
      build_servers! config

      project_options = config[:project]
      if @server && @server.project_api_id
        project_options.merge!(api_id: @server.project_api_id)
      end

      @project.update(project_options)

      @scm.update(config[:scm])

      yield self if block_given?
    end

    def initialize_servers
      @server = Server.new name: 'default'
      @servers = []
    end

    def validate

      # If the selected server is not configured, it means that the configuration is incomplete somehow.
      if @server.empty?
        if @servers == [ @server ]
          # If the list of servers contains only the default, non-configured server, it means
          # that no server was defined in any of the configuration files, and that none of the
          # server environment variables were given.
          @load_warnings << "No server defined"
        elsif !@server_name
          # Otherwise, if there are configured servers in the list but none are selected, it
          # means that no server name was given.
          @load_warnings << "No server name given"
        elsif !@servers.collect(&:name).include?(@server_name)
          # Otherwise, if a server name was given, it means that it does not match any of the
          # configured servers.
          @load_warnings << "Unknown server #{@server_name}"
        end
      end

      # If neither the project nor the server are configured, and none of the expected
      # configuration files exist, add a warning.
      if @project.empty? && @server.empty?
        config_files = all_config_files
        actual_config_files = config_files.select{ |f| File.exists?(f) }

        if actual_config_files.empty?
          @load_warnings << %|No config file found, looking for:\n     #{config_files.join("\n     ")}|
        end
      end
    end

    # Builds server objects from the loaded configuration and selects the one that will be used.
    def build_servers! config

      server_options = config[:servers]
      @servers = server_options.keys.collect do |name|
        Server.new(server_options[name].merge(name: name))
      end

      selected_server_name = @server_name.to_s.strip

      # Remove the default server from the list if it is not configured and other servers are.
      default_server = @servers.find{ |server| server.name == 'default' }
      @servers.delete(default_server) if default_server && default_server.empty? && @servers.length >= 2

      # Select the server based on the specified server name, or use the default one.
      if @server_name && server = @servers.find{ |server| server.name == selected_server_name }
        @server = server
      elsif !@server_name
        @server = default_server
      end
    end

    def home_config_file
      File.join(File.expand_path('~'), '.probedock', 'config.yml')
    end

    def working_config_file
      File.expand_path(parse_env_string(:config) || 'probedock.yml', Dir.pwd)
    end

    def all_config_files
      [ home_config_file, working_config_file ]
    end

    # Builds an empty standard configuration hash.
    def empty_config
      {
        payload: {},
        project: {},
        scm: {
          remote: {
            url: {}
          }
        },
        servers: {}
      }
    end

    # Builds a standard configuration hash from a YAML configuration file.
    def load_config_file(file)

      config = {}
      contents = YAML.load_file(file)

      # Parse general options.
      config.merge!(parse_general_options(contents))

      # Parse configuration objects.
      %i(payload project scm).each do |name|
        config[name] = send("parse_#{name}_options", contents[name.to_s])
      end

      # Parse the server objects.
      config[:servers] = {}
      if contents['servers'].kind_of?(Hash)
        config[:servers] = contents['servers'].inject({}) do |memo,(name,options)|
          memo[name] = parse_server_options(options)
          memo
        end
      end

      config.reject{ |k,v| v.nil? }
    end

    # Builds a standard configuration hash from the supported `PROBEDOCK_*` environment variables.
    def load_env_config(previous_config)

      env_options = {
        publish: parse_env_flag(:publish),
        server: parse_env_string(:server),
        local: parse_env_flag(:local),
        workspace: parse_env_string(:workspace),
        payload: {
          print: parse_env_flag(:print_payload),
          save: parse_env_flag(:save_payload)
        }.reject{ |k,v| v.nil? },
        project: {
          api_id: parse_env_string(:project_api_id),
          version: parse_env_string(:project_version)
        }.reject{ |k,v| v.nil? },
        scm: {
          name: parse_env_string(:scm_name),
          version: parse_env_string(:scm_version),
          dirty: parse_env_flag(:scm_dirty),
          remote: {
            name: parse_env_string(:scm_remote_name),
            ahead: parse_env_integer(:scm_remote_ahead),
            behind: parse_env_integer(:scm_remote_behind),
            url: {
              fetch: parse_env_string(:scm_remote_url_fetch),
              push: parse_env_string(:scm_remote_url_push)
            }.reject{ |k,v| v.nil? }
          }.reject{ |k,v| v.nil? }
        }.reject{ |k,v| v.nil? },
        servers: {}
      }.reject{ |k,v| v.nil? }

      # Determine the selected server name based on environment variables
      # and previously parsed configuration files.
      server_name = if env_options.key?(:server)
        # If the PROBEDOCK_SERVER option was given, then that server name is selected.
        env_options[:server]
      elsif previous_config[:server] && previous_config[:servers].key?(previous_config[:server])
        # Otherwise if a server name was already selected in the configuration files,
        # then that server name is selected.
        previous_config[:server]
      else
        # Otherwise, the server name "default" is selected.
        'default'
      end

      # The PROBEDOCK_SERVER_* environment variables can be used to configure
      # a server from scratch (with no need for configuration files).
      #
      # They can also be used to override the selected server (see previous code block).
      if server_name
        env_options[:servers] = {
          server_name => {
            api_url: parse_env_string(:server_api_url),
            api_token: parse_env_string(:server_api_token),
            project_api_id: parse_env_string(:server_project_api_id)
          }.reject{ |k,v| v.nil? }
        }
      end

      env_options
    end

    # Deep-merges all the configuration hashes given as arguments,
    # in order of increasing precedence (e.g. the last configuration will
    # override all previous ones).
    def merge_configs(*configs)
      configs.inject do |memo,config|
        merge_config(memo, config)
      end
    end

    # Deep-merges the two specified configuration hashes, with properties
    # in the second one overriding the first.
    #
    # This method expects the configuration hashes to have the standard format:
    #
    #     {
    #       payload: {},
    #       project: {},
    #       scm: {
    #         remote: {
    #           url: {}
    #         }
    #       },
    #       servers: {}
    #     }
    #
    # It is the responsibility of the caller to supply configuration hashes
    # in this format.
    def merge_config(config, config_override)

      # Iterate over both configurations' keys.
      (config.keys + config_override.keys).uniq.inject({}) do |memo,key|

        memo[key] = if config[key].kind_of?(Hash) || config_override[key].kind_of?(Hash)
          # If the current values are hashes, recursively merge them.
          merge_config(config[key] || {}, config_override[key] || {})
        elsif config[key].kind_of?(Array) || config_override[key].kind_of?(Array)
          # If the current values are arrays, return the duplicate-free union of the two.
          # WARNING: recursive merging is not currently supported for arrays. Arrays are
          # expected to contain primitives only (e.g. tags).
          ((config[key] || []) + (config_override[key] || [])).uniq
        else
          # If the current values are primitives, take the second configuration's
          # value if present, otherwise the first's.
          config_override.fetch(key, config[key])
        end

        memo
      end
    end

    def parse_env_option(name)

      var = "PROBEDOCK_#{name.to_s.upcase}"
      return ENV[var] if ENV.key? var

      old_var = "PROBE_DOCK_#{name.to_s.upcase}"
      ENV.key?(old_var) ? ENV[old_var] : nil
    end

    def parse_env_flag(name, default = nil)
      val = parse_env_option name
      val ? !!val.to_s.strip.match(/\A(1|y|yes|t|true)\Z/i) : default
    end

    def parse_env_integer(name, default = nil)
      val = parse_env_option name
      val ? val.to_i : default
    end

    def parse_env_string(name, default = nil)
      val = parse_env_option name
      val ? val.to_s : default
    end

    def parse_general_options(h)
      parse_typed_options(h, {
        publish: :boolean,
        server: :string,
        local: :boolean,
        workspace: :string
      })
    end

    def parse_server_options(h)
      parse_typed_options(h, {
        name: :string,
        apiUrl: :string,
        apiToken: :string,
        projectApiId: :string
      })
    end

    def parse_payload_options(h)
      parse_typed_options(h, {
        save: :boolean,
        print: :boolean
      })
    end

    def parse_project_options(h)
      parse_typed_options(h, {
        version: :string,
        apiId: :string,
        category: :string,
        tags: :string_array,
        tickets: :string_array
      })
    end

    def parse_scm_options(h)
      scm_options = parse_typed_options(h, {
        name: :string,
        version: :string,
        dirty: :boolean
      })

      scm_remote = h.kind_of?(Hash) ? h['remote'] : {}
      scm_options[:remote] = parse_typed_options(scm_remote, {
        name: :string,
        ahead: :integer,
        behind: :integer
      })

      scm_remote_url = scm_remote.kind_of?(Hash) ? scm_remote['url'] : {}
      scm_options[:remote][:url] = parse_typed_options(scm_remote_url, {
        fetch: :string,
        push: :string
      })

      scm_options
    end

    def parse_typed_options(h, parse)
      return {} unless h.kind_of?(Hash)

      result = parse.inject({}) do |memo,(key,config)|

        if h.key?(key.to_s)
          underscored_key = key.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase.to_sym
          memo[underscored_key] = send("parse_#{config}_option", h[key.to_s])
        end

        memo
      end

      result.reject{ |k,v| v.nil? }
    end

    def parse_boolean_option(value, default = nil)
      if value.nil?
        default
      elsif !!value == value
        value
      else
        !!value.to_s.match(/^(1|y|yes|t|true)$/i)
      end
    end

    def parse_string_array_option(value, default = [])
      if value.nil?
        default
      elsif value.kind_of?(Array)
        value.collect(&:to_s)
      else
        [ value.to_s ]
      end
    end

    def parse_string_option(value, default = nil)
      value.nil? ? default : (value.kind_of?(String) ? value : value.to_s)
    end

    def parse_integer_option(value, default = nil)
      if value.nil?
        default
      elsif value.kind_of?(Integer)
        value
      else
        value.to_s.to_i
      end
    end
  end
end
