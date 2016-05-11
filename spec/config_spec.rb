require 'helper'
require 'fileutils'

describe ProbeDockProbe::Config, fakefs: true do
  include Capture::Helpers
  Server ||= ProbeDockProbe::Server
  Scm ||= ProbeDockProbe::Scm
  Project ||= ProbeDockProbe::Project

  let(:config){ described_class.new }
  let(:probedock_env_vars){ {} }
  subject{ config }

  before :each do
    @probedock_env_vars = ENV.select{ |k,v| k.match /\APROBEDOCK_/ }.each_key{ |k| ENV.delete k }
    probedock_env_vars.each_pair{ |k,v| ENV["PROBEDOCK_#{k.upcase}"] = v.to_s }
  end

  after :each do
    @probedock_env_vars.each_pair{ |k,v| ENV[k] = v }
  end

  describe "when created" do
    subject{ described_class }

    it "should create a project, scm and server configuration" do
      expect(Project).to receive(:new)
      expect(Scm).to receive(:new)
      expect(Server).to receive(:new)
      subject.new
    end
  end

  describe "default attributes" do
    its(:publish?){ should be(false) }
    its(:local_mode?){ should be(false) }
    its(:project){ should be_a(Project) }
    its(:scm){ should be_an(Scm) }
    its(:print_payload?){ should be(false) }
    its(:save_payload?){ should be(false) }
    its(:servers){ should be_empty }
    its(:server){ should have_server_configuration(name: 'default') }
    its(:workspace){ should be_nil }
  end

  it "should expand the workspace" do
    subject.workspace = 'foo'
    expect(subject.workspace).to eq(File.expand_path('foo'))
  end

  describe "when loaded" do
    let(:home_config){ nil }
    let(:home_config_path){ File.expand_path('~/.probedock/config.yml') }
    let(:project_config){ nil }
    let(:project_config_path){ '/project/probedock.yml' }
    let(:config_block){ nil }
    let(:loaded_config_capture){ capture{ config.tap{ |c| c.load!(&config_block) } } }
    let(:loaded_config){ loaded_config_capture.result }

    before :each do
      FileUtils.mkdir_p '/project'
      FileUtils.mkdir_p File.dirname(home_config_path)
      FileUtils.mkdir_p File.dirname(project_config_path)
      File.open(home_config_path, 'w'){ |f| f.write(normalize_config_yaml(home_config)) } if home_config
      File.open(project_config_path, 'w'){ |f| f.write(normalize_config_yaml(project_config)) } if project_config
      Dir.chdir '/project'
    end

    # This shared examples group can be applied to check that a configuration
    # was properly loaded without errors.
    #
    # Override the following `let` blocks to define configuration sources:
    #
    # * `home_config` - The home configuration file (~/.probedock/config.yml).
    # * `project_config` - The project configuration file (probedock.yml in the working directory by default).
    # * `probedock_env_vars` - Probe Dock environment variables in underscore format
    #                          (e.g. `print_payload` automatically becomes PROBEDOCK_PRINT_PAYLOAD
    #                          and its value is serialized as a string).
    # * `config_block` - A block passed to the `config#load!` method.
    #                    It will receive the configuration being loaded as argument.
    #
    # It expects the following `let` blocks to be defined:
    #
    # * `expected_project_configuration`
    # * `expected_scm_configuration`
    # * `expected_client_options`
    # * `expected_servers`
    # * `expected_selected_server`
    shared_examples_for "a loaded configuration" do
      it "should have no load warnings" do
        expect(loaded_config.load_warnings).to be_empty
        expect(loaded_config_capture.stdout).to be_empty
        expect(loaded_config_capture.stderr).to be_empty
      end

      it "should update the project" do

        project = config.project
        expect(project).to receive(:clear).and_call_original
        expect(project).to receive(:update).and_call_original

        config.load!(&config_block)

        actual_project = %i(api_id version category tags tickets).inject({}){ |memo,attr| memo[attr] = project.send(attr); memo }.reject{ |k,v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }

        expect(normalize_project_config(actual_project)).to eq(normalize_project_config(expected_project_configuration))
      end

      it "should update the scm configuration" do

        scm = config.scm
        expect(config.scm).to receive(:update).and_call_original

        config.load!(&config_block)

        actual_scm = %i(name version dirty).inject({}){ |memo,attr| memo[attr] = scm.send(attr); memo }.reject{ |k,v| v.nil? }
        actual_scm[:remote] = %i(name ahead behind).inject({}){ |memo,attr| memo[attr] = scm.remote.send(attr); memo }.reject{ |k,v| v.nil? }
        actual_scm[:remote][:url] = %i(fetch push).inject({}){ |memo,attr| memo[attr] = scm.remote.url.send(attr); memo }.reject{ |k,v| v.nil? }

        expect(actual_scm).to eq(expected_scm_configuration)
      end

      it "should return client options" do
        expect(loaded_config.client_options).to eq(expected_client_options)
      end

      it "should create the server(s)" do
        config.load!(&config_block)

        actual_servers = config.servers.collect do |server|
          %i(name api_url api_token project_api_id).inject({}){ |memo,k| memo[k] = server.send(k); memo }.reject{ |k,v| v.nil? }
        end

        expect(actual_servers).to eq(expected_servers)
      end

      it "should select the specified server" do
        server = expected_selected_server ? loaded_config.servers.find{ |server| server.name == expected_selected_server } : loaded_config.server
        expect(loaded_config.server).to eq(server)
      end
    end

    # The tests in this block demonstrate the various ways to achieve a
    # minimal working configuration.
    describe "with minimal information" do
      let :expected_project_configuration do
        {
          version: '1.2.3',
          api_id: 'abcdef'
        }
      end

      let :expected_scm_configuration do
        {
          remote: {
            url: {}
          }
        }
      end

      let :expected_client_options do
        {
          publish: true,
          local_mode: false,
          print_payload: false,
          save_payload: false
        }
      end

      let :expected_servers do
        [
          {
            name: 'default',
            api_url: 'http://example.com/api',
            api_token: 'secret'
          }
        ]
      end

      let :expected_selected_server, &->{ nil }

      # This test demonstrates that a minimal working configuration can be achieved
      # using only the home configuration file.
      describe "in the home config" do
        let :home_config do
          <<-CONFIG
            servers:
              a:
                apiUrl: "http://example.com/api"
                apiToken: secret
            project:
              version: 1.2.3
              apiId: abcdef
            server: a
          CONFIG
        end

        let :expected_selected_server, &->{ 'a' }
        let :expected_servers, &->{ super().tap{ |servers| servers[0][:name] = 'a' } }

        it_should_behave_like "a loaded configuration"
      end

      # This test demonstrates that a minimal working configuration can be achieved
      # using only the project configuration file.
      describe "in the project config" do
        let :project_config do
          <<-CONFIG
            servers:
              a:
                apiUrl: "http://example.com/api"
                apiToken: secret
            project:
              version: 1.2.3
              apiId: abcdef
            server: a
          CONFIG
        end

        let :expected_selected_server, &->{ 'a' }
        let :expected_servers, &->{ super().tap{ |servers| servers[0][:name] = 'a' } }

        it_should_behave_like "a loaded configuration"
      end

      # This test demonstrates that a minimal working configuration can be achieved
      # using only the project configuration file and environment variables.
      # This is one way to support public continuous integration platforms like Travis CI.
      describe "in the project config and environment variables" do
        let :project_config do
          <<-CONFIG
            project:
              version: 1.2.3
              apiId: abcdef
          CONFIG
        end

        let :probedock_env_vars do
          {
            server_api_url: 'http://example.com/api',
            server_api_token: 'secret'
          }
        end

        it_should_behave_like "a loaded configuration"
      end

      # This test demonstrates that a minimal working configuration can be achieved
      # using only environment variables. This is one way to support public continuous
      # integration platforms like Travis CI.
      describe "in environment variables" do
        let :probedock_env_vars do
          {
            project_api_id: 'abcdef',
            project_version: '1.2.3',
            server_api_url: 'http://example.com/api',
            server_api_token: 'secret'
          }
        end

        it_should_behave_like "a loaded configuration"
      end

      # This test demonstrates that a minimal working configuration can be achieved
      # by providing a block. This is one way to support public continuous integration
      # platforms like Travis CI.
      describe "in a block" do
        let :config_block do
          lambda do |config|
            config.project.api_id = 'abcdef'
            config.project.version = '1.2.3'
            config.server.api_url = 'http://example.com/api'
            config.server.api_token = 'secret'
          end
        end

        it_should_behave_like "a loaded configuration"
      end
    end

    # This test demonstrates that all configuration properties can be set
    # in the home configuration file.
    describe "with full information in the home config" do
      let :home_config do
        <<-CONFIG
          servers:
            a:
              apiUrl: "http://example.com/api"
              apiToken: secret
              projectApiId: bcdefg
            b:
              apiUrl: "http://subdomain.example.com/api"
              apiToken: secret2
          project:
            version: 1.2.3
            apiId: abcdef
            category: A category
            tags: [ a, b ]
            tickets: [ t1, t2, t3 ]
          publish: true
          local: true
          server: a
          workspace: /old
          payload:
            print: true
            save: false
          scm:
            name: git
            version: 2.7.2
            dirty: true
            remote:
              name: origin
              ahead: 4
              behind: 2
              url:
                fetch: git@github.com:probedock/probedock-ruby.git
                push: https://github.com/probedock/probedock.git
        CONFIG
      end

      let :expected_project_configuration do
        {
          version: '1.2.3',
          api_id: 'bcdefg',
          category: 'A category',
          tags: %w(a b),
          tickets: %w(t1 t2 t3)
        }
      end

      let :expected_scm_configuration do
        {
          name: 'git',
          version: '2.7.2',
          dirty: true,
          remote: {
            name: 'origin',
            ahead: 4,
            behind: 2,
            url: {
              fetch: 'git@github.com:probedock/probedock-ruby.git',
              push: 'https://github.com/probedock/probedock.git'
            }
          }
        }
      end

      let :expected_client_options do
        {
          publish: true,
          local_mode: true,
          print_payload: true,
          save_payload: false,
          workspace: '/old'
        }
      end

      let :expected_servers do
        [
          {
            name: 'a',
            api_url: 'http://example.com/api',
            api_token: 'secret',
            project_api_id: 'bcdefg'
          },
          {
            name: 'b',
            api_url: 'http://subdomain.example.com/api',
            api_token: 'secret2'
          }
        ]
      end

      let :expected_selected_server, &->{ 'a' }

      it_should_behave_like "a loaded configuration"

      # This test demonstrates that all configuration properties in the home
      # configuration file can be overriden in the project configuration file.
      describe "with overrides in the project config" do
        let :project_config do
          <<-CONFIG
            servers:
              a:
                apiToken: secret3
              b:
                apiUrl: "http://another-subdomain.example.com/api"
                apiToken: secret4
            project:
              version: 2.3.4
              apiId: cdefgh
              category: Another category
              tags: oneTag
            payload:
              print: false
              save: true
            publish: false
            local: false
            workspace: /tmp
            server: b
            scm:
              name: custom
              version: 1.2.3
              dirty: false
              remote:
                name: upstream
                ahead: 3
                behind: 23
                url:
                  fetch: https://github.com/probedock/probedock-node.git
                  push: git@github.com:probedock/probedock.git
          CONFIG
        end

        let :expected_project_configuration do
          {
            version: '2.3.4',
            api_id: 'cdefgh',
            category: 'Another category',
            tags: %w(a b oneTag),
            tickets: %w(t1 t2 t3)
          }
        end

        let :expected_scm_configuration do
          {
            name: 'custom',
            version: '1.2.3',
            dirty: false,
            remote: {
              name: 'upstream',
              ahead: 3,
              behind: 23,
              url: {
                fetch: 'https://github.com/probedock/probedock-node.git',
                push: 'git@github.com:probedock/probedock.git'
              }
            }
          }
        end

        let :expected_client_options do
          {
            publish: false,
            local_mode: false,
            print_payload: false,
            save_payload: true,
            workspace: '/tmp'
          }
        end

        let :expected_servers do
          [
            {
              name: 'a',
              api_url: 'http://example.com/api',
              api_token: 'secret3',
              project_api_id: 'bcdefg'
            },
            {
              name: 'b',
              api_url: 'http://another-subdomain.example.com/api',
              api_token: 'secret4'
            }
          ]
        end

        let :expected_selected_server, &->{ 'b' }

        it_should_behave_like "a loaded configuration"

        # This test demonstrates that some configuration properties in the
        # home and project configuration files can be overriden with environment
        # variables.
        describe "with overrides in environment variables" do
          let :probedock_env_vars do
            {
              publish: true,
              local: true,
              print_payload: true,
              save_payload: false,
              workspace: '/tmp/environment',
              server: 'a',
              server_api_url: 'http://environment.com/api',
              server_api_token: 'secret42',
              server_project_api_id: 'defghi',
              scm_name: 'mercurial',
              scm_version: '2.3.4',
              scm_dirty: true,
              scm_remote_name: 'bitbucket',
              scm_remote_ahead: 17,
              scm_remote_behind: 0,
              scm_remote_url_fetch: 'git@bitbucket.org:probedock/probedock.git',
              scm_remote_url_push: 'https://user@bitbucket.org/probedock/probedock.git'
            }
          end

          let :expected_project_configuration do
            {
              version: '2.3.4',
              api_id: 'defghi',
              category: 'Another category',
              tags: %w(a b oneTag),
              tickets: %w(t1 t2 t3)
            }
          end

          let :expected_scm_configuration do
            {
              name: 'mercurial',
              version: '2.3.4',
              dirty: true,
              remote: {
                name: 'bitbucket',
                ahead: 17,
                behind: 0,
                url: {
                  fetch: 'git@bitbucket.org:probedock/probedock.git',
                  push: 'https://user@bitbucket.org/probedock/probedock.git'
                }
              }
            }
          end

          let :expected_client_options do
            {
              publish: true,
              local_mode: true,
              print_payload: true,
              save_payload: false,
              workspace: '/tmp/environment'
            }
          end

          let :expected_servers do
            [
              {
                name: 'a',
                api_url: 'http://environment.com/api',
                api_token: 'secret42',
                project_api_id: 'defghi'
              },
              {
                name: 'b',
                api_url: 'http://another-subdomain.example.com/api',
                api_token: 'secret4'
              }
            ]
          end

          let :expected_selected_server, &->{ 'a' }

          it_should_behave_like "a loaded configuration"

          # This test demonstrates that most configuration properties in the
          # home and project configuration files and in environment variables
          # can be overriden by providing a block.
          describe "with overrides in environment variables" do
            let :config_block do
              lambda do |config|
                config.publish = false
                config.local_mode = false
                config.print_payload = false
                config.save_payload = true
                config.workspace = '/tmp/block'
                config.project.api_id = 'efghij'
                config.project.version = '3.4.5'
                config.project.category = 'Yet another category'
                config.project.tags << 'c'
                config.project.tickets.shift
                config.scm.name = 'git'
                config.scm.version = '4.5.6'
                config.scm.dirty = false
                config.scm.remote.name = 'foo'
                config.scm.remote.ahead = 16
                config.scm.remote.behind = 2
                config.scm.remote.url.fetch = 'git@github.com:probedock/probedock.git'
                config.scm.remote.url.push = 'https://github.com/probedock/probedock-node.git'
                config.server.api_url = 'http://block.com/api'
                config.server.api_token = 'secret24'
                config.server.project_api_id = 'cdefgh'
              end
            end

            let :expected_project_configuration do
              {
                version: '3.4.5',
                api_id: 'efghij',
                category: 'Yet another category',
                tags: %w(a b c oneTag),
                tickets: %w(t2 t3)
              }
            end

            let :expected_scm_configuration do
              {
                name: 'git',
                version: '4.5.6',
                dirty: false,
                remote: {
                  name: 'foo',
                  ahead: 16,
                  behind: 2,
                  url: {
                    fetch: 'git@github.com:probedock/probedock.git',
                    push: 'https://github.com/probedock/probedock-node.git'
                  }
                }
              }
            end

            let :expected_client_options do
              {
                publish: false,
                local_mode: false,
                print_payload: false,
                save_payload: true,
                workspace: '/tmp/block'
              }
            end

            let :expected_servers do
              [
                {
                  name: 'a',
                  api_url: 'http://block.com/api',
                  api_token: 'secret24',
                  project_api_id: 'cdefgh'
                },
                {
                  name: 'b',
                  api_url: 'http://another-subdomain.example.com/api',
                  api_token: 'secret4'
                }
              ]
            end

            let :expected_selected_server, &->{ 'a' }

            it_should_behave_like "a loaded configuration"
          end
        end
      end
    end

    # This test demonstrates that all configuration properties can be set
    # in the project configuration file.
    describe "with full information in the project config" do
      let :project_config do
        <<-CONFIG
          servers:
            a:
              apiUrl: "http://example.com/api"
              apiToken: secret
              projectApiId: bcdefg
            b:
              apiUrl: "http://subdomain.example.com/api"
              apiToken: secret2
          project:
            version: 1.2.3
            apiId: abcdef
            category: A category
            tags: [ a, b ]
            tickets: [ t1, t2, t3 ]
          publish: true
          local: true
          server: a
          workspace: /old
          payload:
            print: true
            save: false
          scm:
            name: git
            version: 2.7.2
            dirty: true
            remote:
              name: origin
              ahead: 4
              behind: 2
              url:
                fetch: git@github.com:probedock/probedock-ruby.git
                push: https://github.com/probedock/probedock.git
        CONFIG
      end

      let :expected_project_configuration do
        {
          version: '1.2.3',
          api_id: 'bcdefg',
          category: 'A category',
          tags: %w(a b),
          tickets: %w(t1 t2 t3)
        }
      end

      let :expected_scm_configuration do
        {
          name: 'git',
          version: '2.7.2',
          dirty: true,
          remote: {
            name: 'origin',
            ahead: 4,
            behind: 2,
            url: {
              fetch: 'git@github.com:probedock/probedock-ruby.git',
              push: 'https://github.com/probedock/probedock.git'
            }
          }
        }
      end

      let :expected_client_options do
        {
          publish: true,
          local_mode: true,
          print_payload: true,
          save_payload: false,
          workspace: '/old'
        }
      end

      let :expected_servers do
        [
          {
            name: 'a',
            api_url: 'http://example.com/api',
            api_token: 'secret',
            project_api_id: 'bcdefg'
          },
          {
            name: 'b',
            api_url: 'http://subdomain.example.com/api',
            api_token: 'secret2'
          }
        ]
      end

      let :expected_selected_server, &->{ 'a' }

      it_should_behave_like "a loaded configuration"

      # This test demonstrates that some configuration properties in the
      # project configuration file can be overriden with environment
      # variables.
      describe "with overrides in environment variables" do
        let :probedock_env_vars do
          {
            publish: false,
            print_payload: false,
            save_payload: true,
            workspace: '/tmp/environment',
            server: 'b',
            server_api_url: 'http://environment.com/api',
            server_api_token: 'secret42',
            server_project_api_id: 'defghi',
            scm_name: 'mercurial',
            scm_version: '2.3.4',
            scm_dirty: true,
            scm_remote_name: 'bitbucket',
            scm_remote_ahead: 17,
            scm_remote_behind: 0,
            scm_remote_url_fetch: 'git@bitbucket.org:probedock/probedock.git',
            scm_remote_url_push: 'https://user@bitbucket.org/probedock/probedock.git'
          }
        end

        let :expected_project_configuration do
          {
            version: '1.2.3',
            api_id: 'defghi',
            category: 'A category',
            tags: %w(a b),
            tickets: %w(t1 t2 t3)
          }
        end

        let :expected_scm_configuration do
          {
            name: 'mercurial',
            version: '2.3.4',
            dirty: true,
            remote: {
              name: 'bitbucket',
              ahead: 17,
              behind: 0,
              url: {
                fetch: 'git@bitbucket.org:probedock/probedock.git',
                push: 'https://user@bitbucket.org/probedock/probedock.git'
              }
            }
          }
        end

        let :expected_client_options do
          {
            publish: false,
            local_mode: true,
            print_payload: false,
            save_payload: true,
            workspace: '/tmp/environment'
          }
        end

        let :expected_servers do
          [
            {
              name: 'a',
              api_url: 'http://example.com/api',
              api_token: 'secret',
              project_api_id: 'bcdefg'
            },
            {
              name: 'b',
              api_url: 'http://environment.com/api',
              api_token: 'secret42',
              project_api_id: 'defghi'
            }
          ]
        end

        let :expected_selected_server, &->{ 'b' }

        it_should_behave_like "a loaded configuration"

        # This test demonstrates that most configuration properties in the
        # project configuration files and in environment variables can be
        # overriden by providing a block.
        describe "with overrides in environment variables" do
          let :config_block do
            lambda do |config|
              config.publish = false
              config.local_mode = false
              config.print_payload = false
              config.save_payload = true
              config.workspace = '/tmp/block'
              config.project.api_id = 'efghij'
              config.project.version = '3.4.5'
              config.project.category = 'Yet another category'
              config.project.tags << 'c'
              config.project.tickets.shift
              config.scm.name = 'git'
              config.scm.version = '4.5.6'
              config.scm.dirty = false
              config.scm.remote.name = 'foo'
              config.scm.remote.ahead = 16
              config.scm.remote.behind = 2
              config.scm.remote.url.fetch = 'git@github.com:probedock/probedock.git'
              config.scm.remote.url.push = 'https://github.com/probedock/probedock-node.git'
              config.server.api_url = 'http://block.com/api'
              config.server.api_token = 'secret24'
              config.server.project_api_id = 'cdefgh'
            end
          end

          let :expected_project_configuration do
            {
              version: '3.4.5',
              api_id: 'efghij',
              category: 'Yet another category',
              tags: %w(a b c),
              tickets: %w(t2 t3)
            }
          end

          let :expected_scm_configuration do
            {
              name: 'git',
              version: '4.5.6',
              dirty: false,
              remote: {
                name: 'foo',
                ahead: 16,
                behind: 2,
                url: {
                  fetch: 'git@github.com:probedock/probedock.git',
                  push: 'https://github.com/probedock/probedock-node.git'
                }
              }
            }
          end

          let :expected_client_options do
            {
              publish: false,
              local_mode: false,
              print_payload: false,
              save_payload: true,
              workspace: '/tmp/block'
            }
          end

          let :expected_servers do
            [
              {
                name: 'a',
                api_url: 'http://example.com/api',
                api_token: 'secret',
                project_api_id: 'bcdefg'
              },
              {
                name: 'b',
                api_url: 'http://block.com/api',
                api_token: 'secret24',
                project_api_id: 'cdefgh'
              }
            ]
          end

          let :expected_selected_server, &->{ 'b' }

          it_should_behave_like "a loaded configuration"
        end
      end
    end

    # This test demonstrates that a different project configuration file can be loaded
    # through the use of environment variables.
    describe "with a custom project config" do
      let :home_config do
        <<-CONFIG
          servers:
            a:
              apiUrl: "http://example.com/api"
              apiToken: secret
        CONFIG
      end

      let :project_config_path, &->{ '/tmp/custom.yml' }
      let :project_config do
        <<-CONFIG
          project:
            version: 1.2.3
            apiId: abcdef
          server: a
          publish: true
        CONFIG
      end

      let :probedock_env_vars do
        {
          config: '/tmp/custom.yml',
          publish: false
        }
      end

      let :expected_project_configuration do
        {
          version: '1.2.3',
          api_id: 'abcdef'
        }
      end

      let :expected_scm_configuration do
        {
          remote: {
            url: {}
          }
        }
      end

      let :expected_client_options do
        {
          publish: false,
          local_mode: false,
          print_payload: false,
          save_payload: false
        }
      end

      let :expected_servers do
        [
          {
            name: 'a',
            api_url: 'http://example.com/api',
            api_token: 'secret'
          }
        ]
      end

      let :expected_selected_server, &->{ 'a' }

      it_should_behave_like "a loaded configuration"
    end

    describe "load warnings" do
      subject{ loaded_config }

      describe "with no config files" do
        its(:server){ should have_server_configuration(name: 'default') }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(2).items }

        it "should warn that no config file was found and that no server was defined" do
          expect(subject).to have_elements_matching(:load_warnings, /no config file found/i, home_config_path, project_config_path, /no server defined/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no config file found.*/i)
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no server defined.*/i)
        end
      end

      describe "with no server" do
        let(:project_config){ "publish: true" }
        its(:server){ should have_server_configuration(name: 'default') }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(1).items }

        it "should warn that no server was defined" do
          expect(subject).to have_elements_matching(:load_warnings, /no server defined/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no server defined.*/i)
        end
      end

      describe "with no server selected" do
        let :project_config do
          <<-CONFIG
            servers:
              a:
                apiUrl: http://example.com/api
            publish: true
          CONFIG
        end

        its(:server){ should have_server_configuration(name: 'default') }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(1).items }

        it "should warn that no server name was given" do
          expect(subject).to have_elements_matching(:load_warnings, /no server name given/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no server name given.*/i)
        end
      end

      describe "with an unknown server selected" do
        let :project_config do
          <<-CONFIG
            servers:
              a:
                apiUrl: http://example.com/api
            publish: true
            server: unknown
          CONFIG
        end

        its(:server){ should have_server_configuration(name: 'default') }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(1).item }

        it "should warn that no server was found with the specified name" do
          expect(subject).to have_elements_matching(:load_warnings, /unknown server unknown/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*unknown server unknown.*/i)
        end
      end
    end
  end

  def normalize_config_yaml text
    lines = text.split("\n").reject{ |s| s.strip.empty? }.collect(&:rstrip)
    indent = lines[0].length - lines[0].sub(/^\s*/, '').length
    lines.map{ |l| l.sub(/^\s{#{indent}}/, '') }.join("\n")
  end

  def normalize_project_config config

    %i(tags tickets).each do |attr|
      config[attr] = config[attr].sort if config[attr].respond_to?(:sort)
    end

    config
  end
end
