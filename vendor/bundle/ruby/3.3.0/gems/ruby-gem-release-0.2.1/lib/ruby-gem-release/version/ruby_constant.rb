# frozen_string_literal: true

module RubyGemRelease
  module Version
    class RubyConstant
      PATTERN = /\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\z/

      def initialize(path:, constant:)
        raise ArgumentError, 'constant must be a Ruby constant name' unless constant.is_a?(String) && /\A[A-Z]\w*\z/.match?(constant)

        @path = path
        @assignment = /^([ \t]*#{Regexp.escape(constant)}[ \t]*=[ \t]*)(['"])([^'"\r\n]+)\2/
      end

      def read
        value = assignment(File.read(@path))[3]
        parse(value)
        value
      end

      def set(value)
        parse(value)
        content = File.read(@path)
        match = assignment(content)
        content[match.begin(3)...match.end(3)] = value
        File.write(@path, content)
        value
      end

      def increment!(part: :patch)
        parts = parse(read)
        index = { 'major' => 0, 'minor' => 1, 'patch' => 2 }.fetch(part.to_s) do
          raise ArgumentError, 'bump part must be major, minor, or patch'
        end
        parts[index] += 1
        ((index + 1)...parts.size).each { |i| parts[i] = 0 }
        set(parts.join('.'))
      end

      private

      def parse(value)
        match = PATTERN.match(value) if value.is_a?(String)
        raise ArgumentError, "invalid version: #{value.inspect}; expected MAJOR.MINOR.PATCH" unless match

        match.captures.map(&:to_i)
      end

      def assignment(content)
        matches = content.to_enum(:scan, @assignment).map { Regexp.last_match }
        raise ArgumentError, "expected exactly one version assignment in #{@path}" unless matches.one?

        matches.first
      end
    end
  end
end
