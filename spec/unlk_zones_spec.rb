require "spec_helper"

RSpec.describe Untded::UnlkZones do
  def zone(**kw)
    described_class::Zone.new(**kw)
  end

  it "pairs line and position into a zone, attaching the format" do
    expect(described_class.of("UNLK: an..17 L 04, P 63-80")).to eq([
      zone(line_from: 4, line_to: 4, pos_from: 63, pos_to: 80, format: "an..17"),
    ])
  end

  it "handles line ranges, spaced hyphens and zero-based positions as printed" do
    expect(described_class.of("UNLK: L 16, P 45 - 61")).to eq([
      zone(line_from: 16, line_to: 16, pos_from: 45, pos_to: 61, format: nil),
    ])
    expect(described_class.of("UNLK: L 36-46, P 00-08")).to eq([
      zone(line_from: 36, line_to: 46, pos_from: 1, pos_to: 8, format: nil),
    ])
  end

  it "normalizes glued and lowercase notation" do
    expect(described_class.of("UNLK: L15, P 27-44")).to eq([
      zone(line_from: 15, line_to: 15, pos_from: 27, pos_to: 44, format: nil),
    ])
    expect(described_class.of("UNLK: Date only: L 21, p 74-80")).to eq([
      zone(line_from: 21, line_to: 21, pos_from: 74, pos_to: 80, format: nil),
    ])
  end

  it "spans the full line when no positions are printed" do
    expect(described_class.of("UNLK: an..17 L 40")).to eq([
      zone(line_from: 40, line_to: 40, pos_from: 1, pos_to: 82, format: "an..17"),
    ])
  end

  it "drops non-UNLK schemes and unlocatable positions" do
    expect(described_class.of("AWB: L 26, P 45-55 CIMP: (508) n..11")).to eq([])
    expect(described_class.of("UNLK: n..11")).to eq([])
  end

  it "parses the colon-less entry of element 5010 (verbatim source)" do
    expect(described_class.of("UNLK L 24, P45-80")).to eq([
      zone(line_from: 24, line_to: 24, pos_from: 45, pos_to: 80, format: nil),
    ])
  end
end
