module ProbeDockProbe

	ANNOTATION_REGEXP = /@probedock\(([^\(\)]*)\)/

	class Annotation

		attr_reader :key, :category, :tags, :tickets, :active

		def initialize(str)
			parse(str)
		end

		private

		def parse(str)

			@key = nil
			@category = nil
			@tags = []
			@tickets = []
			@active = true

			loop do
				match = str.match(ANNOTATION_REGEXP)

				if match
					text = match[1]

					if text.match(/^[a-z0-9]+$/)
						@key = text
					else
						@key = parseAnnotationValue(text, 'key')
						@category = parseAnnotationValue(text, 'category')
						parseAnnotationList(text, 'tag', @tags)
						parseAnnotationList(text, 'ticket', @tickets)

						active = text.match(/active=["']?(1|0|true|false|yes|no|t|f|y|n)["']?/i)
						if active
							@active = !active[1].match(/^(1|y|yes|t|true)$/i).nil?
						end
					end

					str = str.gsub(ANNOTATION_REGEXP, '')
				else
					break
				end
			end
		end

		def keyword_regexp(keyword)
			/#{keyword}=(?:(?<#{keyword}>[^"' ]+)|["']?(?<#{keyword}>[^"']+)["']?)/
		end

		def parseAnnotationValue(text, keyword)
			match = text.match(keyword_regexp(keyword))
			match ? match[keyword] : nil
		end

		def parseAnnotationList(text, keyword, values)
			regexp = keyword_regexp(keyword)

			loop do
				match = text.match(regexp)

				if match
					values.push(match[keyword])
					text = text.sub(regexp, '')
				end

				break unless match
			end
		end
	end
end
