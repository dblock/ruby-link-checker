# frozen_string_literal: true

module RubyGemRelease
  module Changelog
    class KeepAChangelog < Base
      UNRELEASED = /\A\#{1,6} \[Unreleased\]\z/

      private

      def update_release(version:, date:)
        validate_release(version, date)
        content = File.read(@path)
        separator = newline(content)
        position = heading(content, UNRELEASED)
        check_absent(content, /\A\#{1,6} \[#{Regexp.escape(version)}\] - \d{4}-\d{2}-\d{2}\z/, 'release heading already exists')
        line_end = content.index(separator, position)
        raise ArgumentError, "heading must end with a newline in #{@path}" unless line_end

        content[position...line_end] = "#{heading_prefix(content, position)} [#{version}] - #{date.strftime('%Y-%m-%d')}"
        release_references(content, version, separator)
        File.write(@path, content)
      end

      def update_next(version:, released_version:)
        validate_version(version)
        validate_version(released_version)
        content = File.read(@path)
        separator = newline(content)
        pattern = /\A\#{1,6} \[#{Regexp.escape(released_version)}\] - \d{4}-\d{2}-\d{2}\z/
        position = heading(content, pattern)
        prefix = heading_prefix(content, position)
        check_absent(content, UNRELEASED, 'unreleased heading already exists')
        check_next_reference(content, released_version)

        File.write(@path, content.insert(position, ["#{prefix} [Unreleased]", '', ''].join(separator)))
      end

      def references(content, label)
        return [] unless reference_defined?(content, label)

        pattern = /\A[ \t]{0,3}\[#{Regexp.escape(label)}\]:[ \t]*(.*)\z/i
        matches = []
        editable_lines(content) do |line, offset|
          match = pattern.match(line.chomp)
          matches << [offset, line.chomp, match[1]] if match
        end
        matches
      end

      def reference_defined?(content, label)
        node = document("#{content}\n\n[#{label}]\n").last_child.first_child
        node&.type == :link
      end

      def unreleased_reference(content)
        matches = references(content, 'Unreleased')
        raise ArgumentError, 'duplicate Unreleased reference links' if matches.size > 1

        matches.first
      end

      def comparison(url)
        match = %r{\A(https?://[^\s<>]+/compare/)([^/\s]*?)(\d+\.\d+\.\d+)\.\.\.([^\s<>]+)\z}.match(url)
        raise ArgumentError, 'Unreleased reference must be a comparison URL ending in VERSION...BRANCH' unless match

        match
      end

      def release_references(content, version, separator)
        reference = unreleased_reference(content)
        return unless reference

        raise ArgumentError, 'release reference already exists' unless references(content, version).empty?

        offset, line, url = reference
        match = comparison(url)
        updated = "[Unreleased]: #{match[1]}#{match[2]}#{version}...#{match[4]}"
        released = "[#{version}]: #{match[1]}#{match[2]}#{match[3]}...#{match[2]}#{version}"
        content[offset, line.length] = "#{updated}#{separator}#{released}"
      end

      def check_next_reference(content, released_version)
        reference = unreleased_reference(content)
        return unless reference

        match = comparison(reference[2])
        raise ArgumentError, 'Unreleased comparison must start at the released version' unless match[3] == released_version
      end
    end
  end
end
