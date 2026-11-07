# frozen_string_literal: true

require 'date'
require 'commonmarker'

module RubyGemRelease
  module Changelog
    class Base
      def initialize(path: 'CHANGELOG.md')
        @path = path
      end

      def release!(release)
        update_release(version: release.version, date: release.date)
      end

      def prepare_next!(release)
        update_next(version: release.next_version, released_version: release.version)
      end

      private

      def heading(content, pattern)
        matches = heading_positions(content, pattern)
        raise ArgumentError, "expected exactly one matching heading in #{@path}" unless matches.one?

        matches.first
      end

      def heading_positions(content, pattern, max_level: 6)
        lines = content.lines
        offsets = line_offsets(lines)
        matches = []
        document(content).each do |node|
          next unless node.type == :heading && node.header_level <= max_level

          index = node.source_position[:start_line] - 1
          matches << offsets[index] if pattern.match?(lines[index].chomp)
        end
        matches
      end

      def heading_prefix(content, position)
        content[position, 6][/\A#+/]
      end

      def editable_lines(content)
        excluded = excluded_lines(content)
        offset = 0
        content.each_line.with_index(1) do |line, number|
          yield line, offset unless excluded.include?(number)
          offset += line.length
        end
      end

      def document(content)
        Commonmarker.parse(content, options: { extension: { shortcodes: false } })
      end

      def line_offsets(lines)
        offset = 0
        lines.map do |line|
          position = offset
          offset += line.length
          position
        end
      end

      def excluded_lines(content)
        excluded = Set.new
        document(content).walk do |node|
          next unless %i[code_block html_block block_quote].include?(node.type)

          position = node.source_position
          excluded.merge(position[:start_line]..position[:end_line])
        end
        excluded
      end

      def newline(content)
        raise ArgumentError, "mixed or unsupported line endings in #{@path}" if (content.match?(/(?<!\r)\n/) && content.include?("\r\n")) || content.match?(/\r(?!\n)/)

        content.include?("\r\n") ? "\r\n" : "\n"
      end

      def validate_version(version)
        raise ArgumentError, "invalid version: #{version.inspect}" unless version.is_a?(String) && /\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\z/.match?(version)
      end

      def validate_release(version, date)
        validate_version(version)
        raise ArgumentError, 'date must be a Date' unless date.instance_of?(Date)
      end

      def check_absent(content, pattern, message)
        raise ArgumentError, "#{message} in #{@path}" unless heading_positions(content, pattern).empty?
      end
    end
  end
end
