require "spec_helper"

RSpec.describe Untded::UnclCoverage do
  let(:elements) do
    Untded.elements_from(data_dir)
  end
  let(:mirror_path) do
    File.join(ENV.fetch("UNTDED_REFERENCES_DIR", File.join(project_root, "..", "references")),
              "edifact-D05B", "codes.xml")
  end

  before do
    skip "D05B codes mirror not present" unless File.exist?(mirror_path)
  end

  it "counts code values per coded data element" do
    counts = described_class.counts(mirror_path)
    expect(counts.fetch(3055)).to eq(316)
    expect(counts).not_to have_key(1004)
  end

  it "joins active elements only, every joined tag real" do
    links = described_class.links(elements, described_class.counts(mirror_path))
    expect(links).to include({ "tag" => 3055, "code_values" => 316 })
    expect(links.map { |l| l["tag"] }).to all(satisfy { |t| elements.any? { |e| e.tag == t && e.status == "active" } })
    expect(links.find { |l| l["tag"] == 1004 }).to be_nil
  end

  it "reports mirror ids that are not TDED elements" do
    counts = described_class.counts(mirror_path)
    tags = elements.map(&:tag)
    skipped = described_class.skipped_ids(counts, tags)
    expect(skipped).not_to be_empty
    expect(skipped).to all(satisfy { |id| tags.none? { |t| t == id } })
  end
end
