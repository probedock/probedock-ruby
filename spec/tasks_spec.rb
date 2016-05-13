require 'helper'

describe ProbeDockProbe::Tasks do
  include Capture::Helpers
  UID ||= ProbeDockProbe::UID
  Tasks ||= ProbeDockProbe::Tasks

  let(:uid_options){ { workspace: '/tmp' } }
  let(:uid_double){ double uid_options }
  subject{ Tasks.new(workspace: uid_options[:workspace]) }

  before :each do
    Rake::Task.clear
    allow(UID).to receive(:new).and_return(uid_double)
    subject
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
        expect{ capture(silence_errors: true){ invoke task_name } }.to raise_error(UID::Error, error_message)
      end
    end
  end

  describe "spec:probedock:uid" do
    before :each do
      expect(UID).to receive(:new).with(uid_options)
    end

    it "should generate a uid in the environment" do

      expect(uid_double).to receive(:generate_uid_to_env)
      allow(uid_double).to receive(:generate_uid_to_env).and_return('abc')

      capture{ invoke 'spec:probedock:uid' }.tap do |c|
        expect(c.stdout).to match(/generated uid/i)
        expect(c.stdout).to match('abc')
      end
    end

    it_should_behave_like "a task", 'spec:probedock:uid', :generate_uid_to_env, 'bug1'
  end

  describe "spec:probedock:uid:file" do
    before :each do
      expect(UID).to receive(:new).with(uid_options)
    end

    it "should generate a uid in the uid file" do

      expect(uid_double).to receive(:generate_uid_to_file)
      allow(uid_double).to receive(:generate_uid_to_file).and_return('abc')

      capture{ invoke 'spec:probedock:uid:file' }.tap do |c|
        expect(c.stdout).to match(/generated uid/i)
        expect(c.stdout).to match('abc')
      end
    end

    it_should_behave_like "a task", 'spec:probedock:uid:file', :generate_uid_to_file, 'bug2'
  end

  describe "spec:probedock:uid:clean" do
    before :each do
      expect(UID).to receive(:new).with(uid_options)
    end

    it "should clean the uid" do
      expect(uid_double).to receive(:clean_uid)
      capture{ invoke 'spec:probedock:uid:clean' }.tap do |c|
        expect(c.stdout).to match(/cleaned/i)
      end
    end

    it_should_behave_like "a task", 'spec:probedock:uid:clean', :clean_uid, 'bug3'
  end

  def invoke name
    task(name).invoke
  end

  def task name
    Rake::Task[name]
  end
end
