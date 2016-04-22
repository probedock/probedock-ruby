require 'helper'

describe ProbeDockProbe::TestRun do
	Annotation ||= ProbeDockProbe::Annotation

	describe 'parsing' do
		describe 'annotation without key keyword' do
			subject { Annotation.new('@probedock(abcde)') }
			it 'should be possible' do
				expect(subject.key).to eq('abcde')
			end
		end

		%W[' " #{''}].each do |quote|
			describe_message = if quote.empty?
				'annotation without quote and'
			else
				"annotation with quote [#{quote}] and"
			end

			describe describe_message do
				describe 'key keyword' do
					subject { Annotation.new("@probedock(key=#{quote}abcde#{quote})") }
					it 'should be possible' do
						expect(subject.key).to eq('abcde')
					end
				end

				describe 'category keyword' do
					subject { Annotation.new("@probedock(category=#{quote}ruby#{quote})") }
					it 'should be possible' do
						expect(subject.category).to eq('ruby')
					end
				end

				describe 'only one tag keyword' do
					subject { Annotation.new("@probedock(tag=#{quote}tag1#{quote})") }
					it 'should be possible' do
						expect(subject.tags).to eq(['tag1'])
					end
				end

				describe 'multiple tag keywords' do
					subject { Annotation.new("@probedock(tag=#{quote}tag1#{quote} tag=#{quote}tag2#{quote} tag=#{quote}tag3#{quote})") }
					it 'should be possible' do
						expect(subject.tags).to eq(%w[tag1 tag2 tag3])
					end
				end

				describe 'only one ticket keyword' do
					subject { Annotation.new("@probedock(ticket=#{quote}ticket1#{quote})") }
					it 'should be possible' do
						expect(subject.tickets).to eq(['ticket1'])
					end
				end

				describe 'multiple ticket keywords' do
					subject { Annotation.new("@probedock(ticket=#{quote}ticket1#{quote} ticket=#{quote}ticket2#{quote} ticket=#{quote}ticket3#{quote})") }
					it 'should be possible' do
						expect(subject.tickets).to eq(%w[ticket1 ticket2 ticket3])
					end
				end

				describe 'active keyword should be possible with' do
					%w(1 yes true y t).each do |word|
						it "[#{word}] truthy boolean" do
							expect(Annotation.new("@probedock(active=#{quote}#{word}#{quote})").active).to be_truthy
						end
					end

					%w(0 no false n f).each do |word|
						it "[#{word}] falsey boolean" do
							expect(Annotation.new("@probedock(active=#{quote}#{word}#{quote})").active).to be_falsey
						end
					end
				end
			end
		end

		%w[' "].each do |quote|
			describe "annotation with spaces between quotes [#{quote}] and" do
				describe 'key keyword' do
					subject { Annotation.new("@probedock(key=#{quote}ab cde#{quote})") }
					it 'should be possible' do
						expect(subject.key).to eq('ab cde')
					end
				end

				describe 'category keyword' do
					subject { Annotation.new("@probedock(category=#{quote}ru by#{quote})") }
					it 'should be possible' do
						expect(subject.category).to eq('ru by')
					end
				end

				describe('tag keyword') do
					subject { Annotation.new("@probedock(tag=#{quote}ta g1#{quote})") }
					it 'should be possible' do
						expect(subject.tags).to eq(['ta g1'])
					end
				end

				describe('ticket keyword') do
					subject { Annotation.new("@probedock(ticket=#{quote}tick et1#{quote})") }
					it 'should be possible' do
						expect(subject.tickets).to eq(['tick et1'])
					end
				end
			end
		end

		%w(ticket tag).each do |keyword|
			describe "annotation with duplicated values for [#{keyword}]" do
				subject { Annotation.new("@probedock(#{keyword}=val #{keyword}=val)") }
				it 'should stored only once' do
					expect(subject.send("#{keyword}s")).to eq([ 'val' ])
				end
			end
		end

		%w(key category).each do |keyword|
			describe "latest encountered value for a #{keyword} in annotations" do
				subject { Annotation.new("@probedock(#{keyword}=firstValue) @probedock(#{keyword}=lastValue)")}
				it 'should be kept' do
					expect(subject.send(keyword)).to eq('lastValue')
				end
			end
		end

		%w(ticket tag).each do |keyword|
			describe "values for #{keyword} keywords in annotations" do
				subject { Annotation.new("@probedock(#{keyword}=firstValue) @probedock(#{keyword}=lastValue)")}
				it 'should be combined' do
					expect(subject.send("#{keyword}s")).to eq( %w[firstValue lastValue])
				end
			end
		end
	end

	describe '#merge' do
		describe 'left is replaced by right for key, category and active and combined for tags and tickets' do
			let(:left){ Annotation.new('@probedock(key=lkey category=lcat active=true tag=lta ticket=lti)') }
			let(:right){ Annotation.new('@probedock(key=rkey category=rcat active=false tag=rta ticket=rti)') }
			subject{ left.merge(right) }
			it {
				expect(subject.key).to eq('rkey')
				expect(subject.category).to eq('rcat')
				expect(subject.active).to be_falsey
				expect(subject.tags).to eq(%w(lta rta))
				expect(subject.tickets).to eq(%w(lti rti))
			}
		end

		describe 'left is not replaced by right for key, category and active and not combined for tags and tickets when values are nil' do
			let(:left){ Annotation.new('@probedock(key=lkey category=lcat active=true tag=lta ticket=lti)') }
			let(:right){ Annotation.new('@probedock()') }
			subject{ left.merge(right) }
			it {
				expect(subject.key).to eq('lkey')
				expect(subject.category).to eq('lcat')
				expect(subject.active).to be_truthy
				expect(subject.tags).to eq(%w(lta))
				expect(subject.tickets).to eq(%w(lti))
			}
		end
	end
end