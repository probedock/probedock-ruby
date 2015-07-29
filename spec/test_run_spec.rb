require 'helper'

describe ProbeDockProbe::TestRun do
  TestRun ||= ProbeDockProbe::TestRun
  TestResult ||= ProbeDockProbe::TestResult
  PayloadError ||= ProbeDockProbe::PayloadError

  let(:project_options){ { name: 'A project', version: '1.2.3', api_id: 'abc', category: 'A category', tags: %w(a b), tickets: %w(t1 t2) } }
  let(:project_double){ double project_options.merge(:validate! => nil) }
  subject{ TestRun.new project_double }

  it "should use the supplied project" do
    expect(subject.project).to be(project_double)
  end

  it "should have no duration or uid" do
    expect(subject_attrs(:duration, :uid)).to eq(duration: nil, uid: nil)
  end

  it "should have no results" do
    expect(subject.results).to be_empty
  end

  it "should let its duration and uid be configured" do
    subject.duration = 42
    subject.uid = 'abc'
    expect(subject.duration).to eq(42)
    expect(subject.uid).to eq('abc')
  end

  describe "#add_result" do
    let(:result_options){ { key: 'abc', name: 'Something should work', fingerprint: 'foo' } }
    let(:new_result_double){ double }

    before :each do
      allow(TestResult).to receive(:new).and_return(new_result_double)
    end

    it "should add a new result" do
      expect(TestResult).to receive(:new).with(project_double, result_options)
      add_result
      expect(subject.results).to eq([ new_result_double ])
    end

    it "should not update an existing result" do
      existing_result = double key: 'abc'
      subject.results << existing_result
      expect(TestResult).to receive(:new).with(project_double, result_options)
      add_result key: 'abc'
      expect(subject.results).to eq([ existing_result, new_result_double ])
    end

    describe "#to_h" do
      let(:result_doubles){ [] }
      let(:run_attributes){ { duration: 42 } }
      subject{ super().tap{ |r| run_attributes.each_pair{ |k,v| r.send "#{k}=", v }; r.results.concat result_doubles } }

      describe "with a missing project" do
        let(:project_double){ nil }

        it "should raise an error indicating that the project is missing" do
          expect{ subject.to_h }.to raise_payload_error(/missing project/i)
        end
      end

      describe "when the project fails to validate" do
        let(:project_double){ super().tap{ |d| allow(d).to receive(:validate!).and_raise(PayloadError.new('bug')) } }

        it "should raise a payload error with the same message" do
          expect{ subject.to_h }.to raise_payload_error(/bug/i)
        end
      end

      describe "with results that are missing a key" do
        let(:result_doubles){ [ double(key: 'a', to_h: 1), double(key: nil, name: 'abcd', to_h: 2), double(key: '  ', name: 'bcde', to_h: 3) ] }

        it "should not raise an error" do
          expect{ subject.to_h }.not_to raise_error
        end
      end

      describe "with results that have duplicate keys" do
        let :result_doubles do
          [
            double(key: '1', name: 'abcd', to_h: 1), double(key: '1', name: 'bcde', to_h: 2),
            double(key: '2', to_h: 3),
            double(key: '3', name: 'cdef', to_h: 4), double(key: '3', name: 'defg', to_h: 5), double(key: '3', name: 'efgh', to_h: 6)
          ]
        end

        it "should not raise an error" do
          expect{ subject.to_h }.not_to raise_error
        end
      end

      describe "with valid data" do
        let(:to_h_options){ {} }
        let(:result_doubles){ [ double(key: 'a', to_h: 1), double(key: 'b', to_h: 2), double(key: 'c', to_h: 3) ] }
        subject{ super().to_h to_h_options }

        let :expected_result do
          {
            'projectId' => 'abc',
            'version' => '1.2.3',
            'duration' => 42,
            'results' => [ 1, 2, 3 ]
          }
        end

        it "should serialize the run data" do
          result_doubles.each{ |d| expect(d).to receive(:to_h).with(to_h_options) }
          expect(subject).to eq(expected_result)
        end

        describe "with an uid" do
          let(:run_attributes){ super().merge uid: '123' }

          it "should serialize the run data with the uid" do
            expect(subject).to eq(expected_result.merge 'reports' => [ { 'uid' => '123' } ])
          end
        end
      end
    end

    def add_result options = {}
      subject.add_result result_options.merge(options)
    end
  end

  def raise_payload_error *args
    raise_error PayloadError do |err|
      args.each{ |m| expect(err.message).to match(m) }
    end
  end

  def subject_attrs *attrs
    attrs.inject({}){ |memo,a| memo[a.to_sym] = subject.send(a); memo }
  end
end
