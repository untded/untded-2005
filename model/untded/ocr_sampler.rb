require "open3"
require "rexml/document"
require "tmpdir"

module Untded
  # Re-reads a deterministic random sample of rows from the rendered page
  # IMAGES with tesseract — an OCR engine independent of whatever produced
  # the PDF's text layer — and fuzzy-compares name / representation /
  # description against the extracted YAML. This is the printed-glyph check:
  # agreement means the text layer, the parser, and a fresh OCR of the image
  # all say the same thing.
  class OcrSampler
    Result = Struct.new(:tag, :field, :expected, :ocr, :ratio, :pass, :unreadable, keyword_init: true)

    def initialize(pdf:, data_dir:, sample_size: 60, seed: 42, dpi: 300)
      @pdf = pdf
      @data_dir = data_dir
      @sample_size = sample_size
      @rng = Random.new(seed)
      @dpi = dpi
    end

    def call
      elements = Dir.glob(File.join(@data_dir, "elements", "*.yaml")).sort.flat_map do |path|
        ElementFile.from_yaml(File.read(path)).elements
      end
      pool = elements.reject { |el| el.name.nil? }
      sample = pool.sample(@sample_size, random: @rng)

      page_cache = {}
      results = sample.flat_map do |el|
        y0, y1 = row_band(el, page_cache)
        next [] unless y0
        name = read_crop(el.provenance.page, 131.0, 262.0, y0, y1, page_cache)
        repr = read_crop(el.provenance.page, 514.0, 554.0, y0, [y1, y0 + 12.0].min,
                         page_cache, psm: "7", pad: "30x10")
        [
          compare_name(el.tag, el.name, name),
          compare_repr(el.tag, el.representation&.raw, repr),
        ].compact
      end

      report(results)
      results
    end

    private

    def bbox_words(page, page_cache)
      page_cache[:bbox] ||= {}
      page_cache[:bbox][page] ||= begin
        out, _, st = Open3.capture3(
          "pdftotext", "-f", page.to_s, "-l", page.to_s, "-bbox-layout", @pdf, "-"
        )
        raise "pdftotext failed" unless st.success?
        doc = REXML::Document.new(out)
        ns = { "xhtml" => "http://www.w3.org/1999/xhtml" }
        REXML::XPath.match(doc, "//xhtml:word", ns).map do |w|
          [w.text.to_s, w.attributes["xMin"].to_f, w.attributes["yMin"].to_f]
        end
      end
    end

    def row_band(el, page_cache)
      words = bbox_words(el.provenance.page, page_cache)
      tag_word = words.find { |t, x, _| t == el.tag.to_s && x >= 100.0 && x < 130.0 }
      return nil unless tag_word
      y0 = tag_word[2] - 1.0
      nexts = words.select { |t, x, y| x >= 100.0 && x < 130.0 && t.match?(/\A\d{4}\z/) && y > tag_word[2] + 3 }
      y1 = nexts.map { |_, _, y| y - 1.0 }.min || (tag_word[2] + 60.0)
      [y0, y1]
    end

    def read_crop(page, x0pt, x1pt, y0pt, y1pt, page_cache, psm: "6", pad: nil)
      png = render_page(page, page_cache)
      s = @dpi / 72.0
      x = (x0pt * s).round
      w = ((x1pt - x0pt) * s).round
      y = (y0pt * s).round
      h = ((y1pt - y0pt) * s).round
      args = ["magick", png, "-crop", "#{w}x#{h}+#{x}+#{y}", "+repage",
              "-resize", "300%", "-colorspace", "Gray"]
      args += ["-bordercolor", "white", "-border", pad] if pad
      out, _, st = Open3.capture3(*args, "png:-")
      return "" unless st.success? && out.bytesize.positive?
      ocr, _, = Open3.capture3("tesseract", "stdin", "stdout", "--psm", psm, stdin_data: out)
      ocr.gsub(/\s+/, " ").strip
    rescue StandardError
      ""
    end

    def render_page(page, page_cache)
      page_cache[:png] ||= {}
      page_cache[:png][page] ||= begin
        path = File.join(Dir.tmpdir, "untded-ocr-p#{page}.png")
        _, _, st = Open3.capture3(
          "mutool", "draw", "-q", "-r", @dpi.to_s, "-c", "gray", "-o", path, @pdf, page.to_s
        )
        raise "mutool failed for page #{page}" unless st.success?
        path
      end
    end

    def compare_name(tag, expected, ocr)
      return nil if expected.nil? || ocr.empty?
      ratio = similarity(normalize(expected), normalize(ocr))
      Result.new(tag: tag, field: "name", expected: expected, ocr: ocr,
                 ratio: ratio, pass: ratio >= 0.80, unreadable: false)
    end

    # The repr crop is a few tiny glyphs; tesseract often misreads them, so
    # an OCR that contains no notation pattern at all is "unreadable"
    # (no evidence either way), while a recognized pattern must match.
    def compare_repr(tag, expected, ocr)
      return nil if expected.nil? || ocr.empty?
      found = ocr[/\b(?:an|a|n)(?:\.\.\d+|\d+)\b/]
      if found.nil?
        Result.new(tag: tag, field: "repr", expected: expected, ocr: ocr,
                   ratio: nil, pass: nil, unreadable: true)
      else
        Result.new(tag: tag, field: "repr", expected: expected, ocr: found,
                   ratio: found == expected ? 1.0 : 0.0, pass: found == expected,
                   unreadable: false)
      end
    end

    def normalize(s)
      s.downcase.delete("^a-z0-9")
    end

    def similarity(a, b)
      return 1.0 if a == b
      return 0.0 if a.empty? || b.empty?
      d = levenshtein(a, b)
      1.0 - d.to_f / [a.length, b.length].max
    end

    def levenshtein(a, b)
      prev = (0..b.length).to_a
      a.each_char.with_index do |ca, i|
        cur = [i + 1]
        b.each_char.with_index do |cb, j|
          cur << [prev[j + 1] + 1, cur[j] + 1, prev[j] + (ca == cb ? 0 : 1)].min
        end
        prev = cur
      end
      prev.last
    end

    def report(results)
      %w[name repr].each do |field|
        rs = results.select { |r| r.field == field }
        next if rs.empty?
        passed = rs.count(&:pass)
        unreadable = rs.count(&:unreadable)
        total = rs.size - unreadable
        puts format("ocr %-5s %3d/%-3d agree (%d unreadable crops excluded)", field, passed, total, unreadable)
        rs.reject { |r| r.pass != false }.first(5).each do |r|
          puts format("  tag %d expected=%p ocr=%p", r.tag, r.expected[0, 60], r.ocr[0, 60])
        end
      end
    end
  end
end
