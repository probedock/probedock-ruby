require 'helper'

describe ProbeDockProbe::TestResult do
  Annotation ||= ProbeDockProbe::Annotation
	TestResult ||= ProbeDockProbe::TestResult

  let(:project_options){ { category: 'A category', tags: %w(a b), tickets: %w(t1 t2) } }
  let(:project_double){ double project_options }
  let(:result_options){ { key: '123', name: 'Something should work', fingerprint: 'foo', passed: true, duration: 42 } }
  let(:result){ TestResult.new project_double, result_options }
  subject{ result }

  it 'should use the given key' do
    expect(subject.key).to eq('123')
  end

  it 'should use the given name' do
    expect(subject.name).to eq('Something should work')
  end

  it 'should use the given fingerprint' do
    expect(subject.fingerprint).to eq('foo')
  end

  it 'should use the category, tags and tickets of the project' do
    expect(subject.category).to eq(project_options[:category])
    expect(subject.tags).to eq(project_options[:tags])
    expect(subject.tickets).to eq(project_options[:tickets])
  end

  it 'should use the supplied result data' do
    expect(subject.passed?).to be(true)
    expect(subject.duration).to eq(42)
    expect(subject.message).to be_nil
  end

  %i(fingerprint name passed duration).each do |missing_option|
    describe "with no :#{missing_option} option" do
      let(:result_options){ super().delete_if{ |k,v| k == missing_option } }
      subject{ described_class }

      it 'should raise an error' do
        expect{ TestResult.new project_double, result_options }.to raise_error(ProbeDockProbe::Error)
      end
    end
  end

  describe 'when failing' do
    let(:result_options){ super().merge passed: false, duration: 12, message: 'Oops' }

    it 'should use the supplied result data' do
      expect(subject.passed?).to be(false)
      expect(subject.duration).to eq(12)
      expect(subject.message).to eq('Oops')
    end
  end

  describe 'with no project category, tags or tickets' do
    let(:project_options){ { category: nil, tags: [], tickets: [] } }

    it 'should have no category, tags, tickets or contributors' do
      expect(subject.category).to be_nil
      expect(subject.tags).to be_empty
      expect(subject.tickets).to be_empty
    end
  end

  describe 'with custom category, tags and tickets' do
    let(:result_options){ super().merge category: 'Another category', tags: %w(b c d), tickets: %w(t3) }

    it 'should override the category of the project' do
      expect(subject.category).to eq('Another category')
    end

    it "should combine the custom tags and the project's" do
      expect(subject.tags).to match_array(%w(a b c d))
    end

    it "should combine the custom tickets and the project's" do
      expect(subject.tickets).to match_array(%w(t1 t2 t3))
    end
	end

	describe 'annotations' do
		describe 'through the test name' do
			let(:result_options) { super().merge(name: 'Something should work @probedock(key=1234 category=cat tag=at1 tag=at2 ticket=ati1 ticket=ati2 active=f)' )}
      it 'should be possible' do
        expect(subject.key).to eq('1234')
				expect(subject.category).to eq('cat')
				expect(subject.active).to be_falsey
				expect(subject.tags).to eq(%w(at1 at2 a b))
				expect(subject.tickets).to eq(%w(ati1 ati2 t1 t2))
      end
		end

		describe 'through string annotation options' do
			let(:result_options) { super().merge(annotation: '@probedock(key=1234 category=cat tag=at1 tag=at2 ticket=ati1 ticket=ati2 active=f)' )}
      it 'should be possible' do
        expect(subject.key).to eq('1234')
				expect(subject.category).to eq('cat')
				expect(subject.active).to be_falsey
				expect(subject.tags).to eq(%w(at1 at2 a b))
				expect(subject.tickets).to eq(%w(ati1 ati2 t1 t2))
			end
		end

		describe 'through object annotation options' do
			let(:result_options) { super().merge(annotation: Annotation.new('@probedock(key=1234 category=cat tag=at1 tag=at2 ticket=ati1 ticket=ati2 active=f)') )}
			it 'should be possible' do
				expect(subject.key).to eq('1234')
				expect(subject.category).to eq('cat')
				expect(subject.active).to be_falsey
				expect(subject.tags).to eq(%w(at1 at2 a b))
				expect(subject.tickets).to eq(%w(ati1 ati2 t1 t2))
			end
		end
	end

  describe '#to_h' do
    let(:to_h_options){ {} }
    let(:result_options){ super().merge message: 'Yeehaw!', active: true }
    subject{ super().to_h to_h_options }

    let :expected_result do
      {
        k: '123',
        n: 'Something should work',
        f: 'foo',
        p: true,
        d: 42,
        m: 'Yeehaw!',
        c: 'A category',
				v: true,
        g: %w(a b),
        t: %w(t1 t2),
        a: {}
      }
    end

    it 'should serialize the result' do
      expect(subject).to eq(expected_result)
    end

    describe 'with no message, category, tags, tickets or contributors' do
      let(:project_options){ { category: nil, tags: nil, tickets: nil } }
      let(:result_options){ super().merge message: nil }

      it 'should reset them' do
        expect(subject).to eq(expected_result.delete_if{ |k,v| k == :m }.merge({ c: nil, g: [], t: [] }))
      end
    end

    describe 'with a name that is too long' do
      let(:result_options){ super().merge name: 'x ' * 130 }

      it 'should truncate the name' do
        expect(subject).to eq(expected_result.merge(n: "#{'x ' * 126}..."))
      end
    end
  end
end
