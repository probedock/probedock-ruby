require 'helper'

describe ProbeDockProbe::TestResult do
  TestResult ||= ProbeDockProbe::TestResult

  let(:project_options){ { category: 'A category', tags: %w(a b), tickets: %w(t1 t2) } }
  let(:project_double){ double project_options }
  let(:result_options){ { key: '123', name: 'Something should work', fingerprint: 'foo', passed: true, duration: 42 } }
  let(:result){ TestResult.new project_double, result_options }
  subject{ result }

  it "should use the given key" do
    expect(subject.key).to eq('123')
  end

  it "should use the given name" do
    expect(subject.name).to eq("Something should work")
  end

  it "should use the given fingerprint" do
    expect(subject.fingerprint).to eq('foo')
  end

  it "should use the category, tags and tickets of the project" do
    expect(subject.category).to eq(project_options[:category])
    expect(subject.tags).to eq(project_options[:tags])
    expect(subject.tickets).to eq(project_options[:tickets])
  end

  it "should use the supplied result data" do
    expect(subject.passed?).to be(true)
    expect(subject.duration).to eq(42)
    expect(subject.message).to be_nil
  end

  %i(fingerprint name passed duration).each do |missing_option|
    describe "with no :#{missing_option} option" do
      let(:result_options){ super().delete_if{ |k,v| k == missing_option } }
      subject{ described_class }

      it "should raise an error" do
        expect{ TestResult.new project_double, result_options }.to raise_error(ProbeDockProbe::Error)
      end
    end
  end

  describe "when failing" do
    let(:result_options){ super().merge passed: false, duration: 12, message: 'Oops' }

    it "should use the supplied result data" do
      expect(subject.passed?).to be(false)
      expect(subject.duration).to eq(12)
      expect(subject.message).to eq('Oops')
    end
  end

  describe "with no project category, tags or tickets" do
    let(:project_options){ { category: nil, tags: [], tickets: [] } }

    it "should have no category, tags or tickets" do
      expect(subject.category).to be_nil
      expect(subject.tags).to be_empty
      expect(subject.tickets).to be_empty
    end
  end

  describe "with custom category, tags and tickets" do
    let(:result_options){ super().merge category: 'Another category', tags: %w(b c d), tickets: %w(t3) }

    it "should override the category of the project" do
      expect(subject.category).to eq('Another category')
    end

    it "should combine the custom tags and the project's" do
      expect(subject.tags).to match_array(%w(a b c d))
    end

    it "should combine the custom tickets and the project's" do
      expect(subject.tickets).to match_array(%w(t1 t2 t3))
    end
  end

  describe "when grouped" do
    let(:result_options){ super().merge grouped: true }

    it "should mark the result as grouped" do
      expect(subject.grouped?).to be(true)
    end

    it "should use the given data" do
      expect(subject.key).to eq('123')
      expect(subject.name).to eq("Something should work")
      expect(subject.fingerprint).to eq('foo')
      expect(subject.category).to eq(project_options[:category])
      expect(subject.tags).to eq(project_options[:tags])
      expect(subject.tickets).to eq(project_options[:tickets])
      expect(subject.passed?).to be(true)
      expect(subject.duration).to eq(42)
      expect(subject.message).to be_nil
    end
  end

  describe "#update" do
    let(:updates){ [] }
    subject{ super().tap{ |s| updates.each{ |u| s.update u } } }

    it "should not concatenate missing messages" do
      subject.update passed: true, duration: 1
      subject.update passed: true, duration: 2
      subject.update passed: true, duration: 3
      expect(subject.message).to be_nil
    end

    describe "with failing result data" do
      let(:update_options){ { passed: false, duration: 24, message: 'Foo' } }
      let(:updates){ super() << update_options }

      it "should mark the result as failed" do
        expect(subject.passed?).to be(false)
      end

      it "should increase the duration" do
        expect(subject.duration).to eq(66)
      end

      it "should set the message" do
        expect(subject.message).to eq('Foo')
      end

      describe "and passing result data" do
        let(:other_update_options){ { passed: true, duration: 600, message: 'Bar' } }
        let(:updates){ super() << other_update_options }

        it "should keep the result marked as failed" do
          expect(subject.passed?).to be(false)
        end

        it "should increase the duration" do
          expect(subject.duration).to eq(666)
        end

        it "should concatenate the messages" do
          expect(subject.message).to eq("Foo\n\nBar")
        end
      end
    end
  end

  describe "#to_h" do
    let(:to_h_options){ {} }
    let(:result_options){ super().merge message: 'Yeehaw!' }
    subject{ super().to_h to_h_options }

    let :expected_result do
      {
        'k' => '123',
        'n' => 'Something should work',
        'f' => 'foo',
        'p' => true,
        'd' => 42,
        'm' => 'Yeehaw!',
        'c' => 'A category',
        'g' => [ 'a', 'b' ],
        't' => [ 't1', 't2' ],
        'a' => {}
      }
    end

    it "should serialize the result" do
      expect(subject).to eq(expected_result)
    end

    describe "with no message, category, tags or tickets" do
      let(:project_options){ { category: nil, tags: nil, tickets: nil } }
      let(:result_options){ super().merge message: nil }

      it "should reset them" do
        expect(subject).to eq(expected_result.delete_if{ |k,v| k == 'm' }.merge({ 'c' => nil, 'g' => [], 't' => []}))
      end
    end
  end
end
