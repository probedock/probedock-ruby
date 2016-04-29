module ProbeDockProbe
  class Annotation
    BASE_REGEXP_STRING = '@probedock\(([^\(\)]*)\)'
    ANNOTATION_REGEXP = /#{BASE_REGEXP_STRING}/
    STRIP_ANNOTATION_REGEXP = /\s*#{BASE_REGEXP_STRING}/

    attr_reader :key, :category, :tags, :tickets, :active

    def initialize(str)
      parse(str)
    end

    def merge!(annotation)
      @key = annotation.key if annotation.key
      @category = annotation.category if annotation.category
      @active = annotation.active unless annotation.active.nil?
      @tags = (@tags + annotation.tags).compact.collect(&:to_s).uniq
      @tickets = (@tickets + annotation.tickets).compact.collect(&:to_s).uniq
      self
    end

    def self.strip_annotations(test_name)
      test_name.gsub(STRIP_ANNOTATION_REGEXP, '')
    end

    private

    def parse(str)
      @key = nil
      @category = nil
      @tags = []
      @tickets = []
      @active = nil

      loop do
        match = str.match(ANNOTATION_REGEXP)

        if match
          text = match[1]

          if text.match(/^[a-z0-9]+$/)
            @key = text
          else
            @key = parse_annotation_value(text, 'key')
            @category = parse_annotation_value(text, 'category')
            parse_annotation_list(text, 'tag', @tags)
            parse_annotation_list(text, 'ticket', @tickets)

            active = text.match(/active=["']?(1|0|true|false|yes|no|t|f|y|n)["']?/i)
            if active
              @active = !active[1].match(/^(1|y|yes|t|true)$/i).nil?
            end
          end

          str = str.sub(ANNOTATION_REGEXP, '')
        else
          break
        end
      end
    end

    def keyword_regexp(keyword)
      /#{keyword}=(?:(?<#{keyword}>[^"' ]+)|["']?(?<#{keyword}>[^"']+)["']?)/
    end

    def parse_annotation_value(text, keyword)
      match = text.match(keyword_regexp(keyword))
      match ? match[keyword] : nil
    end

    def parse_annotation_list(text, keyword, values)
      regexp = keyword_regexp(keyword)

      loop do
        match = text.match(regexp)

        if match
          values.push(match[keyword]) unless values.include?(match[keyword])
          text = text.sub(regexp, '')
        end

        break unless match
      end
    end
  end
end
