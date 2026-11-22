# frozen_string_literal: true

# Generates the ruby-link-checker logo and wordmarks in this directory.
#
#   ruby assets/logo.rb path/to/Inter-Bold.ttf
#
# The wordmark text is set in Inter Bold and converted to outlines, so the
# SVGs render without the font. Colors are from the Ruby logo at
# https://www.ruby-lang.org/images/header-ruby-logo.svg.

require 'bundler/inline'

gemfile(true, quiet: true) do
  source 'https://rubygems.org'
  gem 'ttfunk', '~> 1.8'
end

module Logo
  # Ruby logo colors, light to dark.
  COLORS = {
    highlight: '#fcb19d',
    bright: '#e62923',
    red: '#e2242a',
    medium: '#cf251f',
    deep: '#b8211c',
    dark: '#9e0c00'
  }.freeze

  # A faceted gem on a 256x256 canvas: a crown above the girdle (y=100) and a pavilion down to the culet.
  FACETS = [
    [[28, 100], [76, 52], [92, 100], :bright],
    [[76, 52], [128, 52], [92, 100], :medium],
    [[128, 52], [164, 100], [92, 100], :highlight],
    [[128, 52], [180, 52], [164, 100], :medium],
    [[180, 52], [228, 100], [164, 100], :deep],
    [[28, 100], [92, 100], [128, 208], :bright],
    [[92, 100], [164, 100], [128, 208], :red],
    [[164, 100], [228, 100], [128, 208], :dark]
  ].freeze

  CHECK = '<path d="M90 116 L118 144 L170 92" fill="none" stroke="#ffffff" stroke-width="18" ' \
          'stroke-linecap="round" stroke-linejoin="round"/>'

  WORDMARK = [['ruby-', :text], ['link', :accent], ['-checker', :text]].freeze
  VARIANTS = {
    'wordmark' => { text: '#24292f', accent: COLORS[:red] },
    'wordmark-dark' => { text: '#f0f6fc', accent: COLORS[:bright] }
  }.freeze

  FONT_SIZE = 64
  TEXT_X = 164
  BASELINE = 104

  module_function

  def gem_shapes
    polygons = FACETS.map do |*points, color|
      %(<polygon points="#{points.map { |x, y| "#{x},#{y}" }.join(' ')}" fill="#{COLORS[color]}"/>)
    end
    polygons.join + CHECK
  end

  def svg(width, height, title, body)
    %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height}" width="#{width}" height="#{height}">) +
      "<title>#{title}</title>#{body}</svg>\n"
  end

  def write(directory, font_path)
    File.write(File.join(directory, 'logo.svg'), svg(256, 256, 'ruby-link-checker', gem_shapes))
    gem = %(<g transform="translate(8 8) scale(0.56)">#{gem_shapes}</g>)
    font = Font.new(font_path)
    runs, width = font.layout(WORDMARK.map(&:first), left: TEXT_X, baseline: BASELINE, size: FONT_SIZE)
    width = (width + 16).ceil
    VARIANTS.each do |name, colors|
      paths = runs.zip(WORDMARK).map { |d, (_text, role)| %(<path fill="#{colors[role]}" d="#{d}"/>) }
      File.write(File.join(directory, "#{name}.svg"), svg(width, 160, 'ruby-link-checker', gem + paths.join))
    end
    text = WORDMARK.map do |run, role|
      role == :accent ? %(<tspan fill="#{COLORS[:red]}">#{run}</tspan>) : run
    end
    source = %(<text x="#{TEXT_X}" y="#{BASELINE}" font-family="Inter" font-size="#{FONT_SIZE}" ) +
             %(font-weight="700" fill="#24292f">#{text.join}</text>)
    File.write(File.join(directory, 'wordmark-source.svg'),
               svg(width, 160, 'ruby-link-checker wordmark (editable source)', gem + source))
  end

  # Reads TrueType glyph outlines and lays out text as SVG path data.
  class Font
    ON_CURVE = 0x01
    X_SHORT = 0x02
    Y_SHORT = 0x04
    REPEAT = 0x08
    X_SAME = 0x10
    Y_SAME = 0x20

    ARGS_ARE_WORDS = 0x0001
    HAS_SCALE = 0x0008
    MORE_COMPONENTS = 0x0020
    HAS_XY_SCALE = 0x0040
    HAS_2X2 = 0x0080

    def initialize(path)
      @file = TTFunk::File.open(path)
      @units_per_em = @file.header.units_per_em.to_f
    end

    # Returns the path data of each run and the x position after the last glyph.
    def layout(runs, left:, baseline:, size:)
      scale = size / @units_per_em
      x = left
      paths = runs.map do |run|
        run.each_char.map do |char|
          id = @file.cmap.unicode.first[char.ord]
          d = contours(id).map { |contour| contour_path(contour, x, baseline, scale) }.join
          x += @file.horizontal_metrics.for(id).advance_width * scale
          d
        end.join
      end
      [paths, x]
    end

    private

    # Returns the glyph's contours as arrays of [x, y, on_curve] in font units.
    def contours(id)
      glyph = @file.glyph_outlines.for(id)
      return [] unless glyph

      data = glyph.raw.byteslice(10..)
      glyph.number_of_contours.negative? ? compound_contours(data) : simple_contours(data, glyph.number_of_contours)
    end

    def simple_contours(data, count)
      ends = data.unpack("n#{count}")
      offset = (count * 2) + 2 + data.byteslice(count * 2, 2).unpack1('n')
      points = ends.last + 1
      flags, offset = read_flags(data, offset, points)
      xs, offset = read_coordinates(data, offset, flags, X_SHORT, X_SAME)
      ys, = read_coordinates(data, offset, flags, Y_SHORT, Y_SAME)
      start = 0
      ends.map do |last|
        contour = (start..last).map { |i| [xs[i], ys[i], flags[i].anybits?(ON_CURVE)] }
        start = last + 1
        contour
      end
    end

    def read_flags(data, offset, points)
      flags = []
      while flags.size < points
        flag = data.getbyte(offset)
        offset += 1
        flags << flag
        next unless flag.anybits?(REPEAT)

        data.getbyte(offset).times { flags << flag }
        offset += 1
      end
      [flags, offset]
    end

    def read_coordinates(data, offset, flags, short, same)
      value = 0
      coordinates = flags.map do |flag|
        if flag.anybits?(short)
          delta = data.getbyte(offset)
          offset += 1
          value += flag.anybits?(same) ? delta : -delta
        elsif flag.nobits?(same)
          value += data.byteslice(offset, 2).unpack1('s>')
          offset += 2
        end
        value
      end
      [coordinates, offset]
    end

    # Combines the components of a compound glyph, applying their offsets and scales.
    def compound_contours(data)
      offset = 0
      contours = []
      loop do
        flags, id = data.byteslice(offset, 4).unpack('nn')
        offset += 4
        dx, dy = data.byteslice(offset, flags.anybits?(ARGS_ARE_WORDS) ? 4 : 2)
                     .unpack(flags.anybits?(ARGS_ARE_WORDS) ? 's>s>' : 'cc')
        offset += flags.anybits?(ARGS_ARE_WORDS) ? 4 : 2
        matrix, offset = read_matrix(data, offset, flags)
        contours += contours(id).map do |contour|
          contour.map do |x, y, on|
            [(matrix[0] * x) + (matrix[2] * y) + dx, (matrix[1] * x) + (matrix[3] * y) + dy, on]
          end
        end
        break if flags.nobits?(MORE_COMPONENTS)
      end
      contours
    end

    def read_matrix(data, offset, flags)
      count = if flags.anybits?(HAS_2X2) then 4
              elsif flags.anybits?(HAS_XY_SCALE) then 2
              elsif flags.anybits?(HAS_SCALE) then 1
              else 0
              end
      values = data.byteslice(offset, count * 2).unpack("s>#{count}").map { |v| v / 16_384.0 }
      matrix = case count
               when 4 then values
               when 2 then [values[0], 0, 0, values[1]]
               when 1 then [values[0], 0, 0, values[0]]
               else [1, 0, 0, 1]
               end
      [matrix, offset + (count * 2)]
    end

    # Converts a quadratic TrueType contour to SVG path data, flipping y onto the baseline.
    def contour_path(contour, left, baseline, scale)
      point = ->((x, y)) { format('%<x>.2f %<y>.2f', x: left + (x * scale), y: baseline - (y * scale)) }
      start_index = contour.index { |p| p[2] }
      if start_index
        contour = contour.rotate(start_index)
        start = contour.first
      else
        first = contour.first
        last = contour.last
        start = [(first[0] + last[0]) / 2.0, (first[1] + last[1]) / 2.0, true]
      end
      commands = ["M#{point.call(start)}"]
      control = nil
      (contour.drop(start_index ? 1 : 0) + [start]).each do |p|
        if p[2]
          commands << (control ? "Q#{point.call(control)} #{point.call(p)}" : "L#{point.call(p)}")
          control = nil
        elsif control
          middle = [(control[0] + p[0]) / 2.0, (control[1] + p[1]) / 2.0]
          commands << "Q#{point.call(control)} #{point.call(middle)}"
          control = p
        else
          control = p
        end
      end
      "#{commands.join}Z"
    end
  end
end

abort 'Usage: ruby assets/logo.rb path/to/Inter-Bold.ttf' unless ARGV.size == 1
Logo.write(__dir__, ARGV.first)
