require "spec_helper"

RSpec.describe Untded::Bridges do
  describe ".entries" do
    it "splits scheme entries as printed" do
      expect(described_class.entries("UNLK: an..17 L 04, P 63-80 MAR: IMO/FAL 1-7")).to eq([
        described_class::Entry.new("UNLK", "an..17 L 04, P 63-80"),
        described_class::Entry.new("MAR", "IMO/FAL 1-7"),
      ])
    end

    it "recognizes the colon-less scheme at the start of the cell (element 5010, verbatim)" do
      expect(described_class.entries("UNLK L 24, P45-80")).to eq([
        described_class::Entry.new("UNLK", "L 24, P45-80"),
      ])
    end

    it "drops text before the first scheme marker" do
      expect(described_class.entries("see form UNLK: L 2")).to eq([
        described_class::Entry.new("UNLK", "L 2"),
      ])
    end

    it "returns nothing without a scheme" do
      expect(described_class.entries("n..11")).to eq([])
      expect(described_class.entries(nil)).to eq([])
    end
  end

  describe ".segments" do
    it "splits format, lines and positions tokens" do
      segs = described_class.segments("an..17 L 04, P 63-80")
      expect(segs.map(&:kind)).to eq(%i[format lines text positions])
      expect(segs[0].text).to eq("an..17")
      expect(segs[1]).to have_attributes(kind: :lines, from: 4, to: nil)
      expect(segs[3]).to have_attributes(kind: :positions, from: 63, to: 80)
    end

    it "reads spaced and glued hyphens alike" do
      segs = described_class.segments("L 45 - 61")
      expect(segs[0]).to have_attributes(kind: :lines, from: 45, to: 61)
    end
  end
end
