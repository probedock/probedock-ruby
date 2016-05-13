require 'helper'

describe ProbeDockProbe::Configurable do
  Configurable ||= ProbeDockProbe::Configurable

  class OtherTest
    include Configurable

    configurable({
      foo: :string
    })
  end

  class Test
    include Configurable

    configurable({
      foo: :boolean,
      bar: :integer,
      baz: :string,
      qux: :string_array,
      corge: OtherTest
    })

    attr_accessor :grault
  end

  subject{ Test.new }

  it "should automatically initialize non-primitive attributes" do
    expect(subject.foo).to be_nil
    expect(subject.bar).to be_nil
    expect(subject.baz).to be_nil
    expect(subject.qux).to eq([])
    expect(subject.corge).to be_a_kind_of(OtherTest)
    expect(subject.corge.foo).to be_nil
  end

  it "should coerce attribute values" do

    subject.foo = 'bar'
    expect(subject.foo).to be(true)

    subject.bar = '4'
    expect(subject.bar).to eq(4)

    subject.bar = 'foo'
    expect(subject.bar).to eq(0)

    subject.baz = 45.6
    expect(subject.baz).to eq('45.6')

    subject.baz = [ 'fo', 0, 'bar' ]
    expect(subject.baz).to eq('["fo", 0, "bar"]')

    subject.qux = 'foo'
    expect(subject.qux).to eq(%w(foo))

    subject.qux = [ 1, true, 'bar' ]
    expect(subject.qux).to eq(%w(1 true bar))

    subject.corge = nil
    expect(subject.corge).to be_a_kind_of(OtherTest)
    expect(subject.corge).to be_empty

    subject.corge = { foo: 'bar' }
    expect(subject.corge).to be_a_kind_of(OtherTest)
    expect(subject.corge.foo).to eq('bar')
  end

  it "should automatically call a custom setter when defining a new type" do

    custom_configurable_class = Class.new do
      include Configurable

      configurable({
        foo: :custom
      })

      private

      def set_custom attr, value
        instance_variable_set("@#{attr}", value)
      end
    end

    custom_configurable = custom_configurable_class.new
    custom_configurable.foo = 'bar'

    expect(custom_configurable.foo).to eq('bar')
  end

  describe "#empty?" do
    it "should indicate whether configurable attributes are empty" do

      expect(subject).to be_empty

      subject.grault = 'foo'
      expect(subject).to be_empty

      subject = Test.new
      subject.foo = true
      expect(subject).not_to be_empty

      subject = Test.new
      subject.bar = 3
      expect(subject).not_to be_empty

      subject = Test.new
      subject.baz = 'foo'
      expect(subject).not_to be_empty

      subject = Test.new
      subject.qux = %w(foo bar)
      expect(subject).not_to be_empty

      subject = Test.new
      subject.corge.foo = 'bar'
      expect(subject).not_to be_empty
    end
  end

  describe "#update" do
    it "should update configurable attributes with the specified hash" do

      subject.update({
        foo: true,
        bar: 42,
        baz: 'foo',
        qux: %w(bar baz),
        corge: {
          foo: 'bar'
        }
      })

      expect(subject.foo).to be(true)
      expect(subject.bar).to eq(42)
      expect(subject.baz).to eq('foo')
      expect(subject.qux).to eq(%w(bar baz))
      expect(subject.corge).to be_a_kind_of(OtherTest)
      expect(subject.corge.foo).to eq('bar')
    end

    it "should not update attributes that are not in the hash" do

      subject.update({
        foo: true,
        baz: 'foo',
        corge: {
          foo: 'bar'
        }
      })

      expect(subject.foo).to be(true)
      expect(subject.bar).to be_nil
      expect(subject.baz).to eq('foo')
      expect(subject.qux).to eq([])
      expect(subject.corge).to be_a_kind_of(OtherTest)
      expect(subject.corge.foo).to eq('bar')
    end
  end

  describe "#clear" do
    it "should clear all configurable attributes" do

      subject.foo = true
      subject.bar = 42
      subject.baz = 'foo'
      subject.qux = %w(bar baz)
      subject.corge.foo = 'bar'

      subject.clear

      expect(subject.foo).to be_nil
      expect(subject.bar).to be_nil
      expect(subject.baz).to be_nil
      expect(subject.qux).to eq([])
      expect(subject.corge).to be_a_kind_of(OtherTest)
      expect(subject.corge.foo).to be_nil
    end
  end

  describe "#to_h" do
    it "should serialize configurable attributes as a hash" do

      subject.foo = true
      subject.bar = 42
      subject.baz = 'foo'
      subject.qux = %w(bar baz)
      subject.corge.foo = 'bar'

      expect(subject.to_h).to eq({
        foo: true,
        bar: 42,
        baz: 'foo',
        qux: %w(bar baz),
        corge: {
          foo: 'bar'
        }
      })
    end

    it "should not serialize missing attributes" do

      subject.bar = 42

      expect(subject.to_h).to eq({
        bar: 42,
        corge: {}
      })
    end
  end

  it "should not allow defining configurable attributes of an invalid type" do
    [ 'foo', true, nil, [] ].each do |invalid_type|
      expect do
        Class.new do
          include Configurable

          configurable({
            foo: invalid_type
          })
        end
      end.to raise_error(%/Unsupported type of configurable attribute #{invalid_type.inspect}; must be either a symbol or a configurable class/)
    end
  end
end
