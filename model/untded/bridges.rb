module Untded
  # Bridge semantics shared by the pipeline and the site: the printed
  # Locations/Bridges column split into scheme entries, and each entry's
  # detail split into format/line/position tokens. Ruby port of the
  # website parser (src/lib/element.ts) — one writer, the website keeps
  # only display concerns.
  module Bridges
    # Schemes exactly as the publication's abbreviation list prints them
    # (introduction, section 1.4).
    SCHEME = /(?:Inland Waterways B\/L|CIMP|UNLK|UNSM|EDIFACT|ODETTE|SWIFT|SAD|MAR|AWB|CMR|CIM|ICC|INV|ISO|B\/L):/.freeze
    SCHEME_WORDS = "Inland Waterways B/L|CIMP|UNLK|UNSM|EDIFACT|ODETTE|SWIFT|SAD|MAR|AWB|CMR|CIM|ICC|INV|ISO|B/L".freeze
    TOKEN = /\b(an\.\.\d+|a\.\.\d+|n\.\.\d+|an\d+|a\d+|n\d+)\b|\bL (\d+)(?:\s*-\s*(\d+))?\b|\bP (\d+)(?:\s*-\s*(\d+))?\b/.freeze

    Entry = Struct.new(:scheme, :detail)

    # "UNLK: … MAR: …" → [{scheme: "UNLK", detail: "…"}, …]. One entry
    # prints its scheme without the colon at the start of the cell
    # (element 5010, verbatim from the publication); text before the
    # first scheme marker is not a bridge and is dropped, as on the
    # website.
    def self.entries(bridges)
      return [] if bridges.nil?
      out = []
      last = 0
      last_scheme = nil
      bridges.scan(SCHEME) do
        m = Regexp.last_match
        out << Entry.new(last_scheme, bridges[last...m.begin(0)].strip) if last_scheme
        last = m.end(0)
        last_scheme = m[0].chomp(":")
      end
      out << Entry.new(last_scheme, bridges[last..].strip) if last_scheme
      return out unless out.empty?
      m = bridges.match(/\A(#{SCHEME_WORDS})\s+(.+)\z/m)
      return [Entry.new(m[1], m[2])] if m
      []
    end

    Segment = Struct.new(:kind, :text, :from, :to, keyword_init: true)

    # "an..17 L 04, P 63-80" → format/lines/positions segments; any other
    # text is kept verbatim as text segments.
    def self.segments(detail)
      out = []
      last = 0
      detail.scan(TOKEN) do |fmt, l_from, l_to, p_from, p_to|
        m = Regexp.last_match
        text = detail[last...m.begin(0)].strip
        out << Segment.new(kind: :text, text: text) unless text.empty?
        if fmt
          out << Segment.new(kind: :format, text: fmt)
        elsif l_from
          out << Segment.new(kind: :lines, from: l_from.to_i, to: l_to&.to_i)
        else
          out << Segment.new(kind: :positions, from: p_from.to_i, to: p_to&.to_i)
        end
        last = m.end(0)
      end
      text = detail[last..].to_s.strip
      out << Segment.new(kind: :text, text: text) unless text.empty?
      out
    end
  end
end
