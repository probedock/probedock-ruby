require 'helper'
require 'fileutils'

describe ProbeDockProbe::Config, fakefs: true do
  include Capture::Helpers
  Server ||= ProbeDockProbe::Server
  Scm ||= ProbeDockProbe::Scm
  Project ||= ProbeDockProbe::Project

  let(:config){ described_class.new }
  let(:project_double){ double update: nil }
  let(:scm_double){ double update: nil }
  let(:probe_dock_env_vars){ {} }
  subject{ config }

  before :each do
    allow(Project).to receive(:new).and_return(project_double)
    allow(Scm).to receive(:new).and_return(scm_double)
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

  before :each do
    @probe_dock_env_vars = ENV.select{ |k,v| k.match /\APROBEDOCK_/ }.each_key{ |k| ENV.delete k }
    probe_dock_env_vars.each_pair{ |k,v| ENV["PROBEDOCK_#{k.upcase}"] = v.to_s }
  end

  after :each do
    @probe_dock_env_vars.each_pair{ |k,v| ENV[k] = v }
  end

  describe "default attributes" do
    its(:publish?){ should be(false) }
    its(:local_mode?){ should be(false) }
    its(:project){ should be(project_double) }
    its(:scm){ should be(scm_double) }
    its(:print_payload?){ should be(false) }
    its(:save_payload?){ should be(false) }
    its(:servers){ should be_empty }
    its(:server){ should have_server_configuration(name: nil) }
    its(:workspace){ should be_nil }
  end

  it "should expand the workspace" do
    subject.workspace = 'foo'
    expect(subject.workspace).to eq(File.expand_path('foo'))
  end

  describe "when loaded" do
    let(:home_config){ nil }
    let(:home_config_path){ File.expand_path('~/.probedock/config.yml') }
    let(:working_config){ nil }
    let(:working_config_path){ '/project/probedock.yml' }
    let(:loaded_config_capture){ capture{ config.tap(&:load!) } }
    let(:loaded_config){ loaded_config_capture.result }

    before :each do
      FileUtils.mkdir_p '/project'
      FileUtils.mkdir_p File.dirname(home_config_path)
      FileUtils.mkdir_p File.dirname(working_config_path)
      File.open(home_config_path, 'w'){ |f| f.write home_config.strip } if home_config
      File.open(working_config_path, 'w'){ |f| f.write working_config.strip } if working_config
      Dir.chdir '/project'
    end

    shared_examples_for "a loaded configuration" do
      it "should have no load warnings" do
        expect(loaded_config.load_warnings).to be_empty
        expect(loaded_config_capture.stdout).to be_empty
        expect(loaded_config_capture.stderr).to be_empty
      end

      it "should update the project" do
        expect(project_double).to receive(:update).with(expected_project_updates)
        config.load!
        expect(config.project).to be(project_double)
      end

      it "should update the scm configuration" do
        expect(scm_double).to receive(:update).with(expected_scm_updates)
        config.load!
        expect(config.scm).to be(scm_double)
      end

      it "should return client options" do
        expect(loaded_config.client_options).to eq(expected_client_options)
      end

      it "should create the server(s)" do
        config.load!

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

    describe "with minimal information in the home config" do
      let :home_config do
%|
servers:
  a:
    apiUrl: "http://example.com/api"
    apiToken: secret
project:
  version: 1.2.3
  apiId: abcdef
publish: true
server: a
|
      end

      let :expected_project_updates do
        {
          version: '1.2.3',
          api_id: 'abcdef'
        }
      end

      let :expected_scm_updates do
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
            name: 'a',
            api_url: 'http://example.com/api',
            api_token: 'secret'
          }
        ]
      end

      let :expected_selected_server, &->{ 'a' }

      it_should_behave_like "a loaded configuration"
    end

    describe "with minimal information in the working directory config and environment variables" do
      let :working_config do
%|
project:
  version: 1.2.3
  apiId: abcdef
publish: true
|
      end

      let :probe_dock_env_vars do
        {
          publish: true,
          server_api_url: 'http://example.com/api',
          server_api_token: 'secret',
          server_project_api_id: 'abcdef'
        }
      end

      let :expected_project_updates do
        {
          version: '1.2.3',
          api_id: 'abcdef'
        }
      end

      let :expected_scm_updates do
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
            api_url: 'http://example.com/api',
            api_token: 'secret',
            project_api_id: 'abcdef'
          }
        ]
      end

      let :expected_selected_server, &->{ nil }

      it_should_behave_like "a loaded configuration"
    end

    describe "with full information in the home config" do
      let :home_config do
%|
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
|
      end

      let :expected_project_updates do
        {
          version: '1.2.3',
          api_id: 'bcdefg',
          category: 'A category',
          tags: %w(a b),
          tickets: %w(t1 t2 t3)
        }
      end

      let :expected_scm_updates do
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

      describe "with overrides in the working directory config" do
        let :working_config do
%|
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
|
        end

        let :expected_project_updates do
          {
            version: '2.3.4',
            api_id: 'cdefgh',
            category: 'Another category',
            tags: 'oneTag',
            tickets: %w(t1 t2 t3)
          }
        end

        let :expected_scm_updates do
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

        describe "with overrides in environment variables" do
          let :probe_dock_env_vars do
            {
              publish: true,
              print_payload: true,
              save_payload: false,
              workspace: '/tmp/environment',
              server: 'a',
              server_api_url: 'http://environment.com/api',
              server_api_token: 'secret42',
              server_project_api_id: 'defghi'
            }
          end

          let :expected_project_updates do
            {
              version: '2.3.4',
              api_id: 'defghi',
              category: 'Another category',
              tags: 'oneTag',
              tickets: %w(t1 t2 t3)
            }
          end

          let :expected_scm_updates do
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
              publish: true,
              local_mode: false,
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
        end
      end
    end

    describe "load warnings" do
      subject{ loaded_config }

      describe "with no config files" do
        its(:server){ should have_server_configuration(name: nil) }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(2).items }

        it "should warn that no config file was found and that no server was defined" do
          expect(subject).to have_elements_matching(:load_warnings, /no config file found/i, home_config_path, working_config_path, /no server defined/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no config file found.*/i)
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no server defined.*/i)
        end
      end

      describe "with no server" do
        let(:working_config){ "publish: true" }
        its(:server){ should have_server_configuration(name: nil) }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(1).items }

        it "should warn that no server was defined" do
          expect(subject).to have_elements_matching(:load_warnings, /no server defined/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no server defined.*/i)
        end
      end

      describe "with no server selected" do
        let(:working_config){ %|
servers:
  a:
    apiUrl: http://example.com/api
publish: true
        | }
        its(:server){ should have_server_configuration(name: nil) }
        its(:publish?){ should be(true) }
        its(:load_warnings){ should have(1).items }

        it "should warn that no server name was given" do
          expect(subject).to have_elements_matching(:load_warnings, /no server name given/i)
          expect(loaded_config_capture.stdout).to be_empty
          expect(loaded_config_capture.stderr).to match(/Probe Dock - .*no server name given.*/i)
        end
      end

      describe "with an unknown server selected" do
        let(:working_config){ %|
servers:
  a:
    apiUrl: http://example.com/api
publish: true
server: unknown
        | }

        its(:server){ should have_server_configuration(name: nil) }
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

  def attrs_hash source, *attrs
    attrs.inject({}){ |memo,a| memo[a.to_sym] = source.send(a); memo }
  end
end
