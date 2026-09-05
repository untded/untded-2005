require "open3"
require "rexml/document"

module Untded
  class Extractor
    Column = Struct.new(:name, :lo, :hi, keyword_init: true)
    Word = Struct.new(:text, :x, :y, keyword_init: true)
    Row = Struct.new(:page, :change_tag, :tag, :cells, keyword_init: true) do
      def initialize(*)
        super
        self.cells = Hash.new { |h, k| h[k] = [] }
      end
    end

    # x ranges in PDF points, calibrated from the bbox layout of the table
    # pages (28-132). Anchor clusters observed on every page: 68.8 (tag),
    # 108.6 (UID), 131.3 (name), 286.6 (description), 523.1 (repr),
    # 558.9 (old name), 612.7 (business term), 705.5 (locations/bridges).
    COLUMNS = [
      Column.new(name: :tag, lo: 60.0, hi: 100.0),
      Column.new(name: :uid, lo: 100.0, hi: 130.0),
      Column.new(name: :name, lo: 130.0, hi: 263.0),
      Column.new(name: :description, lo: 263.0, hi: 516.0),
      Column.new(name: :representation, lo: 516.0, hi: 552.0),
      Column.new(name: :old_name, lo: 552.0, hi: 611.0),
      Column.new(name: :business_term, lo: 611.0, hi: 655.8),
      Column.new(name: :notes, lo: 655.8, hi: 704.0),
      Column.new(name: :bridges, lo: 704.0, hi: 1e9),
    ].freeze

    # Change tags as printed in column [1]. The "c..." tags are combinatorial:
    # c[hanged] with n[ame], d[escription], r[epresentation] parts; u =
    # unchanged from the previous edition; x = retired; add = new element.
    CHANGE_TAGS = %w[add cnd cndr cnr cdr cn cr cd u x].freeze

    # Legend as printed in section 4.1 (PDF p.20): add, cn, cnd, cnr, cndr,
    # x, u. The tags cd/cr/cdr occur in the source table but are outside the
    # printed legend; glyph-count analysis of the rendered page images
    # confirms they are printed that way (not OCR drops), so they are kept
    # verbatim and flagged to the review queue.
    LEGEND_TAGS = %w[add cn cnd cnr cndr x u].freeze

    CATEGORY_BY_RANGE = {
      "1000" => "4.2.1 (1000-1699) documentation, references",
      "2000" => "4.2.2 (2000-2699) Dates, times, periods of time",
      "3000" => "4.2.3 (3000-3699) Parties, addresses, places, countries",
      "4000" => "4.2.4 (4000-4699) Clauses, conditions, terms, instructions",
      "5000" => "4.2.5 (5000-5699) Amounts, charges, percentages",
      "6000" => "4.2.6 (6000-6699) Measure identifiers, quantities (other than monetary)",
      "7000" => "4.2.7 (7000-7699) Goods and articles: descriptions and identifiers",
      "8000" => "4.2.8 (8000-8699) Transport modes, means and equipments",
      "9000" => "4.2.9 (9000-9699) Other data elements (Customs, etc.)",
    }.freeze

    attr_reader :pdf, :pages, :stats, :rows

    def initialize(pdf:, pages: 28..132)
      @pdf = pdf
      @pages = pages
      @stats = {}
      @rows = []
    end

    # Yields [page_num, words] for every page, using the same filtering the
    # extraction itself applies (y >= 79 cuts the column headers, x < 60 cuts
    # the running footer and colophon). Verification tools reuse this stream.
    def each_page_words
      doc = REXML::Document.new(bbox_xml)
      ns = { "xhtml" => "http://www.w3.org/1999/xhtml" }
      return to_enum(:each_page_words) unless block_given?
      REXML::XPath.match(doc, "//xhtml:page", ns).each_with_index do |page, i|
        yield [@pages.first + i, words_for(page)]
      end
    end

    def extract
      rows = []
      pending = nil
      each_page_words do |page_num, words|
        page_rows, lead_lines = split_rows(words, page_num)
        if pending && !lead_lines.empty?
          lead_lines.each { |line| append_line(pending, line) }
        end
        pending = page_rows.last
        rows.concat(page_rows)
      end

      vocab = build_vocabulary(rows)
      elements = []
      reviews = []
      rows.each do |row|
        element, row_reviews = build_element(row, vocab)
        elements << element if element
        reviews.concat(row_reviews)
      end
      @stats = compute_stats(rows, elements, reviews)
      @rows = rows
      [elements, reviews]
    end

    def write_data(dir, elements, reviews)
      require "fileutils"
      FileUtils.mkdir_p(File.join(dir, "elements"))
      elements.group_by { |e| format("%d000", e.tag / 1000) }.each do |range, els|
        category = CATEGORY_BY_RANGE.fetch(range) { "#{range} uncategorized" }
        file = ElementFile.new(category: category, elements: els.sort_by(&:tag))
        path = File.join(dir, "elements", "#{range}-#{range.to_i + 699}.yaml")
        File.write(path, file.to_yaml)
      end
      queue = ReviewQueue.new(entries: reviews.sort_by { |r| [r.page, r.tag || 0, r.field] })
      File.write(File.join(dir, "review-queue.yaml"), queue.to_yaml)
    end

    private

    def bbox_xml
      out, err, st = Open3.capture3(
        "pdftotext", "-f", @pages.first.to_s, "-l", @pages.last.to_s,
        "-bbox-layout", @pdf, "-"
      )
      raise "pdftotext failed: #{err}" unless st.success?
      out
    end

    def words_for(page)
      ns = { "xhtml" => "http://www.w3.org/1999/xhtml" }
      words = []
      REXML::XPath.match(page, ".//xhtml:word", ns).each do |w|
        y = w.attributes["yMin"].to_f
        x = w.attributes["xMin"].to_f
        # y<79 cuts the repeated column-header block; x<60 cuts the running
        # footer ("Page NN") and the closing colophon, which live in the left
        # margin outside every table column
        next if y < 79.0 || x < 60.0
        words << Word.new(text: w.text.to_s, x: x, y: y)
      end
      words.sort_by! { |w| [w.y, w.x] }
      words
    end

    def column_for(word)
      COLUMNS.find { |c| word.x >= c.lo && word.x < c.hi }
    end

    def lineify(words)
      lines = []
      current = []
      words.each do |w|
        if current.empty? || w.y - current.last.y <= 3.0
          current << w
        else
          lines << current
          current = [w]
        end
      end
      lines << current unless current.empty?
      lines
    end

    def row_start?(line)
      tagged = line.select { |w| w.x >= 60.0 && w.x < 100.0 }
      uid = line.select { |w| w.x >= 100.0 && w.x < 130.0 }
      return false unless tagged.size == 1 && uid.size == 1
      CHANGE_TAGS.include?(tagged.first.text.downcase) && uid.first.text.match?(/\A\d{4}\z/)
    end

    # Returns [rows, lead_lines] where lead_lines are continuation lines that
    # appear before the first row on the page (they belong to the previous
    # page's last row).
    def split_rows(words, page_num)
      lines = lineify(words)
      starts = lines.each_index.select { |i| row_start?(lines[i]) }
      rows = []
      lead_lines = starts.empty? ? lines : lines.first(starts.first)
      starts.each_with_index do |start, idx|
        stop = starts[idx + 1] || lines.size
        row = Row.new(page: page_num,
                      change_tag: change_tag_word(lines[start]),
                      tag: uid_word(lines[start]).to_i)
        append_line(row, lines[start])
        lines[(start + 1)...stop].each do |line|
          append_line(row, line)
        end
        rows << row
      end
      [rows, lead_lines]
    end

    def change_tag_word(line)
      line.find { |w| w.x >= 60.0 && w.x < 100.0 }&.text&.downcase
    end

    def uid_word(line)
      line.find { |w| w.x >= 100.0 && w.x < 130.0 }&.text
    end

    def append_line(row, line)
      by_col = Hash.new { |h, k| h[k] = [] }
      line.each do |w|
        col = column_for(w)
        next if col.nil? || col.name == :tag || col.name == :uid
        by_col[col.name] << w.text
      end
      by_col.each { |col, words| row.cells[col] << words.join(" ") }
    end

    # Two vocabulary tiers for detecting mid-word OCR line breaks.
    # strict: certainly-complete words (single-line cells, non-final words).
    # loose: additionally the boundary words of wrapped lines, which are
    # usually complete words too but may be broken halves.
    def build_vocabulary(rows)
      strict = Hash.new(0)
      loose = Hash.new(0)
      rows.each do |row|
        %i[name description old_name business_term].each do |key|
          frags = row.cells[key]
          next if frags.empty?
          words_per_line = frags.map { |f| f.split(/\s+/) }
          if frags.size == 1
            add_words(strict, words_per_line.first)
          else
            words_per_line[0...-1].each do |words|
              add_words(strict, words[0..-2])
              add_word(loose, words.last)
            end
            add_words(strict, words_per_line.last)
          end
        end
      end
      { strict: strict.keys.to_h { |k| [k, strict[k]] },
        loose: loose.keys.to_h { |k| [k, loose[k]] } }
    end

    def add_words(tally, words)
      words.each { |w| add_word(tally, w) }
    end

    def add_word(tally, word)
      clean = word.downcase.gsub(/[^a-z]/, "")
      tally[clean] += 1 if clean.size >= 3
    end

    def join_fragments(frags, vocab)
      return [nil, { wrapped: false, direct_join: false }] if frags.empty?
      text = frags.first.strip
      meta = { wrapped: frags.size > 1, direct_join: false }
      frags.drop(1).each do |frag|
        piece = frag.strip
        first_word = piece.split(/\s+/).first
        rest_words = piece.split(/\s+/).drop(1)
        if text.end_with?("/")
          text = rest_words.empty? ? text + piece : text + first_word + " " + rest_words.join(" ")
          meta[:direct_join] = true
        elsif first_word.match?(/\A[,.;:)]/) && !text.end_with?(" ")
          text = text + piece
          meta[:direct_join] = true
        elsif text.end_with?("-") && piece.match?(/\A[a-z]/)
          text = rest_words.empty? ? text + piece : text + first_word + " " + rest_words.join(" ")
          meta[:direct_join] = true
        elsif first_word.match?(/\A[b-hj-z][,.]?\z/) && text.match?(/[a-z]\z/)
          text = rest_words.empty? ? text + first_word : text + first_word + " " + rest_words.join(" ")
          meta[:direct_join] = true
        elsif piece.match?(/\A[a-z]/) && text.match?(/[a-z]\z/) && vocab_join?(text, piece, vocab)
          head = text.split(/\s+/)[0..-2]
          merged = text.split(/\s+/).last + first_word
          text = (head + [merged] + rest_words).join(" ")
          meta[:direct_join] = true
        else
          text = text + " " + piece
        end
      end
      [text, meta]
    end

    # Direct-join is safe when the raw concatenation of the junction words
    # forms known vocabulary: either the merged word itself, or every
    # "/"-separated part of it (e.g. "Document/m" + "essage" -> the compound
    # "Document/message" whose parts "document" and "message" are both known).
    def vocab_join?(text, piece, vocab)
      merged = text.split(/\s+/).last + piece.split(/\s+/).first
      if merged.include?("/")
        known = vocab[:strict].merge(vocab[:loose])
        merged.split("/").all? do |part|
          p = part.gsub(/[^a-zA-Z]/, "").downcase
          p.size < 3 || known.key?(p)
        end
      else
        p = merged.gsub(/[^a-zA-Z]/, "").downcase
        p.size >= 4 && vocab[:strict].key?(p)
      end
    end

    def build_element(row, vocab)
      reviews = []
      fields = {}
      joined = {}
      %i[name description representation old_name business_term notes bridges].each do |key|
        text, meta = join_fragments(row.cells[key], vocab)
        joined[key] = { text: text, **meta }
      end

      name = joined[:name][:text]
      name = nil if name == "." || name.to_s.strip.empty?
      repr = Representation.from_notation(joined[:representation][:text])

      confidence = :high
      # narrow columns carry OCR mid-word break risk; wide columns wrap at
      # word boundaries which space-joining handles safely
      %i[old_name business_term notes bridges].each do |key|
        confidence = :medium if joined[key][:wrapped]
      end
      confidence = :medium if joined.any? { |_, m| m[:direct_join] }

      if repr.nil? && joined[:representation][:text]
        confidence = :low
        reviews << ReviewEntry.new(
          page: row.page, tag: row.tag, field: "representation",
          raw_fragments: row.cells[:representation],
          issue: "unparsable representation notation",
          confidence: "low"
        )
      end
      if name.nil? && row.change_tag != "x"
        confidence = :low
        reviews << ReviewEntry.new(
          page: row.page, tag: row.tag, field: "name",
          raw_fragments: row.cells[:name],
          issue: "missing name on non-retired element",
          confidence: "low"
        )
      end
      unless CHANGE_TAGS.include?(row.change_tag)
        reviews << ReviewEntry.new(
          page: row.page, tag: row.tag, field: "change_tag",
          raw_fragments: [row.change_tag],
          issue: "unknown change tag",
          confidence: "low"
        )
        return [nil, reviews]
      end
      unless LEGEND_TAGS.include?(row.change_tag)
        confidence = :low
        reviews << ReviewEntry.new(
          page: row.page, tag: row.tag, field: "change_tag",
          raw_fragments: [row.change_tag],
          issue: "change tag outside printed legend (section 4.1)",
          confidence: "low"
        )
      end

      element = Element.new(
        tag: row.tag,
        name: name,
        description: joined[:description][:text],
        representation: repr,
        change_tag: row.change_tag,
        status: row.change_tag == "x" ? "retired" : "active",
        old_name: joined[:old_name][:text],
        business_term: joined[:business_term][:text],
        notes: joined[:notes][:text],
        bridges: joined[:bridges][:text],
        provenance: Provenance.new(
          pdf: File.basename(@pdf),
          page: row.page,
          confidence: confidence.to_s
        )
      )
      [element, reviews]
    end

    def compute_stats(rows, elements, reviews)
      {
        rows: rows.size,
        elements: elements.size,
        reviews: reviews.size,
        change_tags: rows.map(&:change_tag).tally,
        wrapped_cells: rows.sum { |r| r.cells.count { |_, v| v.size > 1 } },
        confidence: elements.map { |e| e.provenance.confidence }.tally,
      }
    end
  end
end
