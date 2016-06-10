require 'helper'

describe ProbeDockProbe::Tasks do
  include Capture::Helpers
  UID ||= ProbeDockProbe::UID
  Tasks ||= ProbeDockProbe::Tasks

  let(:workspace){ '/tmp' }
  let(:uid_options){ {} }
  let(:uid_double){ double uid_options }
  let(:probe_dock_env_vars){ {} }
  subject{ Tasks.new workspace: workspace }

  before :each do
    Rake::Task.clear
    allow(UID).to receive(:new).and_return(uid_double)

    @probe_dock_env_vars = ENV.select{ |k,v| k.match /\APROBEDOCK_/ }.each_key{ |k| ENV.delete k }
    probe_dock_env_vars.each_pair{ |k,v| ENV["PROBEDOCK_#{k.upcase}"] = v }

    subject
  end

  after :each do
    @probe_dock_env_vars.each_pair{ |k,v| ENV[k] = v }
  end

  it "should define Probe Dock rake tasks" do
    expect(task('spec:probedock:uid')).not_to be_nil
    expect(task('spec:probedock:uid:file')).not_to be_nil
    expect(task('spec:probedock:uid:clean')).not_to be_nil
  end

  shared_examples_for "a task" do |task_name,method,error_message|
    let(:uid_double){ double.tap{ |d| allow(d).to receive(method).and_raise(UID::Error.new(error_message)) } }

    it "should output the error message to stderr" do
      c = nil
      expect{ c = capture{ invoke task_name } }.not_to raise_error
      expect(c.stdout).to be_empty
      expect(c.stderr).to match(error_message)
    end

    describe "with trace enabled" do
      before :each do
        options = Rake.application.options
        allow(Rake.application).to receive(:options).and_return(options.dup.tap{ |o| o.trace = true })
      end

      it "should raise the error" do
        expect{ capture{ invoke task_name } }.to raise_error(UID::Error, error_message)
      end
    end
  end

  describe "spec:probedock:uid" do
    let(:uid_options){ super().merge generate_uid_to_env: 'abc' }
    before(:each){ expect(UID).to receive(:new).with(workspace: workspace) }

    it "should generate an uid in the environment" do
      expect(uid_double).to receive(:generate_uid_to_env)
      capture{ invoke 'spec:probedock:uid' }.tap do |c|
        expect(c.stdout).to match(/generated uid/i)
        expect(c.stdout).to match('abc')
      end
    end

    it_should_behave_like "a task", 'spec:probedock:uid', :generate_uid_to_env, 'bug1'
  end

  describe "spec:probedock:uid:file" do
    let(:uid_options){ super().merge generate_uid_to_file: 'abc' }
    before(:each){ expect(UID).to receive(:new).with(workspace: workspace) }

    it "should generate an uid in the uid file" do
      expect(uid_double).to receive(:generate_uid_to_file)
      capture{ invoke 'spec:probedock:uid:file' }.tap do |c|
        expect(c.stdout).to match(/generated uid/i)
        expect(c.stdout).to match('abc')
      end
    end

    it_should_behave_like "a task", 'spec:probedock:uid:file', :generate_uid_to_file, 'bug2'
  end

  describe "spec:probedock:uid:clean" do
    let(:uid_options){ super().merge generate_uid_to_clean: nil }
    before(:each){ expect(UID).to receive(:new).with(workspace: workspace) }

    it "should clean the uid" do
      expect(uid_double).to receive(:clean_uid)
      capture{ invoke 'spec:probedock:uid:clean' }.tap do |c|
        expect(c.stdout).to match(/cleaned/i)
      end
    end

    it_should_behave_like "a task", 'spec:probedock:uid:clean', :clean_uid, 'bug3'
  end

  describe "with the PROBEDOCK_WORKSPACE environment variable" do
    let(:probe_dock_env_vars){ { workspace: '/var/tmp' } }
    subject{ Tasks.new }

    it "should set the workspace from the environment variable" do
      expect(UID).to receive(:new).with(workspace: '/var/tmp')

      expect(uid_double).to receive(:clean_uid)
      capture{ invoke 'spec:probedock:uid:clean' }.tap do |c|
        expect(c.stdout).to match(/cleaned/i)
      end
    end
  end

  def invoke name
    task(name).invoke
  end

  def task name
    Rake::Task[name]
  end
end
