module Untded
  # UNLK locations as structured zones: a line span, a character-position
  # span, and the field format token. Semantics only — the millimetre
  # geometry of the form is a display concern of the website.
  module UnlkZones
    POSITIONS_PER_LINE = 82

    Zone = Struct.new(:line_from, :line_to, :pos_from, :pos_to, :format, keyword_init: true)

    def self.of(bridges)
      entry = Bridges.entries(bridges).find { |e| e.scheme == "UNLK" }
      return [] unless entry

      # The printed cells vary: "L15", lowercase "p 74-80", "P 00-08".
      detail = entry.detail
        .gsub(/\b([LP])(\d)/, '\1 \2')
        .gsub(/\b([lp])(\s+\d)/) { "#{Regexp.last_match(1).upcase}#{Regexp.last_match(2)}" }

      zones = []
      pending = nil
      format = nil
      flush = lambda do
        if pending
          zones << Zone.new(line_from: pending[0], line_to: pending[1],
                            pos_from: 1, pos_to: POSITIONS_PER_LINE, format: format)
        end
        pending = nil
      end

      Bridges.segments(detail).each do |seg|
        case seg.kind
        when :lines
          flush.call
          pending = [seg.from, seg.to || seg.from]
        when :positions
          if pending
            zones << Zone.new(line_from: pending[0], line_to: pending[1],
                               pos_from: [1, seg.from].max,
                               pos_to: [1, seg.to || seg.from].max,
                               format: format)
            pending = nil
            format = nil
          end
        when :format
          format = seg.text
        end
      end
      flush.call
      zones
    end
  end
end
