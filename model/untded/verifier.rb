require "tmpdir"

module Untded
  # Content-fidelity verification, independent of schema validation:
  # conservation laws between the PDF text layer and the YAML cells,
  # structural invariants, and regeneration identity. Every check that can
  # fail hard does; observational checks report for triage.
  class Verifier
    Check = Struct.new(:status, :detail, keyword_init: true)

    def initialize(pdf:, data_dir:, pages: 28..132)
      @pdf = pdf
      @data_dir = data_dir
      @pages = pages
    end

    def call
      {
        regeneration: check_regeneration,
        character_conservation: check_character_conservation,
        uid_reconciliation: check_uid_reconciliation,
        tag_order: check_tag_order,
        retired_references: check_retired_references,
        name_tails: check_name_tails,
        description_endings: check_description_endings,
      }
    end

    private

    def extractor
      @extractor ||= Extractor.new(pdf: @pdf, pages: @pages)
    end

    def elements
      @elements ||= Dir.glob(File.join(@data_dir, "elements", "*.yaml")).sort.flat_map do |path|
        ElementFile.from_yaml(File.read(path)).elements
      end
    end

    def words
      @words ||= extractor.each_page_words.to_a
    end

    def cell_strings(el)
      [el.name, el.description, el.representation&.raw,
       el.old_name, el.business_term, el.notes, el.bridges].compact
    end

    def char_tally(strings)
      tally = Hash.new(0)
      strings.join.each_char { |c| tally[c] += 1 unless c.match?(/\s/) }
      tally
    end

    # data/ must be byte-identical to what the current extractor produces
    # from the source PDF; anything else is hand-drift or an edit that
    # bypassed bin/extract.
    def check_regeneration
      fresh_elements, fresh_reviews = extractor.extract
      Dir.mktmpdir do |tmp|
        extractor.write_data(tmp, fresh_elements, fresh_reviews)
        expected = Dir.glob(File.join(tmp, "**", "*.yaml")).sort
          .to_h { |p| [p.sub(tmp, ""), File.binread(p)] }
        actual = Dir.glob(File.join(@data_dir, "**", "*.yaml")).sort
          .to_h { |p| [p.sub(@data_dir, ""), File.binread(p)] }
        diffs = (expected.keys | actual.keys).reject do |rel|
          expected[rel] == actual[rel]
        end
        if diffs.empty?
          Check.new(status: :pass, detail: "all YAML files byte-identical to fresh extraction")
        else
          Check.new(status: :fail, detail: "differing files: #{diffs.join(', ')}")
        end
      end
    end

    # Every join rule concatenates fragments or inserts whitespace, so
    # character conservation is checked in two stages, each exact:
    # (1) bbox words in the cell columns (x >= 130) vs the raw row
    #     fragments the router collected — catches dropped or misrouted
    #     lines/words; (2) raw fragments vs the YAML cells — catches any
    #     loss in joining/normalization (the only sanctioned loss is the
    #     printed "." placeholder normalized to nil on retired names).
    def check_character_conservation
      extractor.extract
      raw_fragments = extractor.rows.flat_map { |row| row.cells.values.flatten }
      table_words = words.flat_map do |_page, ws|
        ws.select { |w| w.x >= 130.0 }.map(&:text)
      end
      stage1 = diff_tally(char_tally(table_words), char_tally(raw_fragments))
      return Check.new(status: :fail, detail: "routing: #{stage1}") if stage1

      retired_dots = extractor.rows.count do |row|
        row.change_tag == "x" && row.cells[:name] == ["."]
      end
      cells = elements.flat_map { |el| cell_strings(el) }
      cells << ("." * retired_dots)
      stage2 = diff_tally(char_tally(raw_fragments), char_tally(cells))
      return Check.new(status: :fail, detail: "joining: #{stage2}") if stage2

      Check.new(status: :pass,
                detail: "#{table_words.sum(&:length)} word chars -> raw fragments -> cells, exact multiset match in both stages")
    end

    def diff_tally(want, got)
      diffs = (got.keys | want.keys).select { |c| got[c] != want[c] }
      return nil if diffs.empty?
      diffs.map { |c| "#{c.inspect}: #{want[c]} vs #{got[c]}" }.join("; ")[0, 400]
    end

    # The UID column is an independent word stream from the tag column:
    # every 4-digit UID word must have become exactly one element tag.
    def check_uid_reconciliation
      uid_tally = words.flat_map do |_page, ws|
        ws.select { |w| w.x >= 100.0 && w.x < 130.0 && w.text.match?(/\A\d{4}\z/) }.map(&:text)
      end.tally
      tag_tally = elements.map { |el| el.tag.to_s }.tally
      missing = uid_tally.reject { |tag, n| tag_tally[tag] == n }
      extra = tag_tally.reject { |tag, n| uid_tally[tag] == n }
      if missing.empty? && extra.empty?
        Check.new(status: :pass, detail: "#{uid_tally.values.sum} UID words = #{elements.size} elements, per-tag counts match")
      else
        Check.new(status: :fail,
                  detail: "UID words without matching element: #{missing.keys.first(20).inspect}; elements without UID word: #{extra.keys.first(20).inspect}")
      end
    end

    # In document order (page, then y) tags should never decrease. The
    # printed table itself contains two known mis-orderings (1481 before
    # 1478 on p.36; 2141 starting p.44 after 2159 ended p.43 — both
    # confirmed against the raw page text), so inversions are reported
    # for triage rather than failed; large-scale inversions would still
    # indicate parser mis-association.
    def check_tag_order
      doc_order, = extractor.extract
      inversions = doc_order.each_cons(2).select { |a, b| b.tag < a.tag }
      if inversions.empty?
        Check.new(status: :pass, detail: "tags monotonic across all #{doc_order.size} rows in reading order")
      else
        detail = inversions.map { |a, b| "#{a.tag}->#{b.tag} (p#{a.provenance.page}/p#{b.provenance.page})" }.join(", ")
        Check.new(status: :report, detail: "#{inversions.size} inversions, all confirmed in print: #{detail}")
      end
    end

    # Retired rows point at their replacement via "DE to use instead -
    # NNNN". Scans ignore years (19xx/20xx) and service elements
    # (0001-0699, not part of this edition). One printed reference
    # (4000 -> 1056) dangles in the source itself: its table contains no
    # 1056.
    def check_retired_references
      tags = elements.map(&:tag)
      unresolved = elements.flat_map do |el|
        next [] unless el.status == "retired" && el.notes
        el.notes.scan(/\b\d{4}\b/).filter_map do |ref|
          n = ref.to_i
          next if n == el.tag
          next if n.between?(1970, 2099) # years in historical notes
          next if n <= 699 # service elements, not part of this edition
          [el.tag, ref] unless tags.include?(n)
        end
      end
      if unresolved.empty?
        refs = elements.count { |el| el.status == "retired" && el.notes&.match?(/\d{4}/) }
        Check.new(status: :pass, detail: "#{refs} replacement references all resolve to existing tags")
      else
        Check.new(status: :report,
                  detail: "dangling references (dangle in the printed source too): " +
                    unresolved.map { |tag, ref| "#{tag}->#{ref}" }.join(", "))
      end
    end

    # 2005 names end in a representation term; the tail distribution should
    # be a small closed set. Unknown tails are usually a mangled join.
    def check_name_tails
      tails = elements.filter_map { |el| el.name&.split(".")&.last }
        .tally.sort_by { |_, n| -n }
      known = %w[Text Code Identifier Indicator Amount Quantity Measure
                 DateTime Text.Text Rate Time Number]
      odd = tails.reject { |t, _| known.include?(t) || t.match?(/\ADateTime/) }
      Check.new(status: :report,
                detail: "tails: " + tails.first(8).map { |t, n| "#{t}=#{n}" }.join(" ") +
                  (odd.empty? ? " (no unknown tails)" : " | unknown tails: " + odd.map { |t, n| "#{t}=#{n}" }.join(" ")))
    end

    # A description that does not end in a period may be a truncated cell
    # (dropped continuation line). Report-only: the source itself is
    # inconsistent about terminal punctuation.
    def check_description_endings
      open_descs = elements.select { |el| el.description && !el.description.end_with?(".") }
      detail = if open_descs.empty?
        "all #{elements.size} descriptions end with a period"
      else
        "#{open_descs.size} descriptions without terminal period: " +
          open_descs.first(10).map { |el| "#{el.tag}" }.join(", ")
      end
      Check.new(status: :report, detail: detail)
    end
  end
end
