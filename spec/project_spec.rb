require 'helper'

describe ProbeDockProbe::Project do
  Project ||= ProbeDockProbe::Project
  PayloadError ||= ProbeDockProbe::PayloadError

  let(:project_options){ { version: '1.2.3', api_id: 'abc', category: 'A category', tags: %w(a b c), tickets: %w(t1 t2) } }
  subject{ Project.new project_options }

  it "should set its attributes from the options" do
    expect(subject_attrs(:version, :api_id, :category, :tags, :tickets)).to eq(project_options)
  end

  describe "without a category option" do
    let(:project_options){ super().delete_if{ |k,v| k == :category } }

    it "should have the RSpec category by default" do
      expect(subject_attrs(:version, :api_id, :category, :tags, :tickets)).to eq(project_options.merge(category: 'RSpec'))
    end
  end

  describe "with no options" do
    subject{ Project.new }

    it "should have the RSpec category by default" do
      expect(subject_attrs(:version, :api_id, :category, :tags, :tickets)).to eq({
        version: nil,
        api_id: nil,
        category: 'RSpec',
        tags: [],
        tickets: []
      })
    end

    it "should keep the RSpec category if not explicitly overriden" do
      subject.update version: '1.2.3', tags: %w(foo bar)
      expect(subject_attrs(:version, :api_id, :category, :tags, :tickets)).to eq({
        version: '1.2.3',
        api_id: nil,
        category: 'RSpec',
        tags: %w(foo bar),
        tickets: []
      })
    end
  end

  describe "#category=" do
    it "should set the category" do
      subject.category = 'Ruby'
      expect(subject.category).to eq('Ruby')
      subject.category = nil
      expect(subject.category).to be_nil
    end
  end

  describe "#update" do
    let(:updates){ { version: '2.3.4', api_id: 'def', category: 'Another category', tags: %w(d e), tickets: [] } }

    it "should update the attributes" do
      subject.update updates
      expect(subject_attrs(:version, :api_id, :category, :tags, :tickets)).to eq(updates)
    end
  end

  describe "#validate!" do
    subject{ Project }

    it "should raise an error if the version is missing" do
      expect{ subject.new(project_options.merge(version: nil)).validate! }.to raise_payload_error(/missing/i, /version/i)
    end

    it "should raise an error if the api identifier is missing" do
      expect{ subject.new(project_options.merge(api_id: nil)).validate! }.to raise_payload_error(/missing/i, /api identifier/i)
    end
  end

  def subject_attrs *attrs
    attrs.inject({}){ |memo,a| memo[a.to_sym] = subject.send(a); memo }
  end

  def raise_payload_error *messages
    raise_error PayloadError do |e|
      messages.each{ |m| expect(e.message).to match(m) }
    end
  end
end
