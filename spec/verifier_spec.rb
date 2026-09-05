require "spec_helper"

RSpec.describe Untded::Verifier do
  subject(:checks) { described_class.new(pdf: source_pdf, data_dir: data_dir).call }

  it "regenerates the SSOT byte-identically" do
    expect(checks[:regeneration].status).to eq(:pass)
  end

  it "conserves every character from text layer to cells" do
    expect(checks[:character_conservation].status).to eq(:pass)
    expect(checks[:character_conservation].detail).to include("169020")
  end

  it "reconciles UID words with elements" do
    expect(checks[:uid_reconciliation].status).to eq(:pass)
    expect(checks[:uid_reconciliation].detail).to include("1504")
  end

  it "reports the two inversions that are printed in the source" do
    expect(checks[:tag_order].status).to eq(:report)
    expect(checks[:tag_order].detail).to include("1481->1478", "2159->2141")
  end

  it "reports the dangling 4000->1056 reference" do
    expect(checks[:retired_references].status).to eq(:report)
    expect(checks[:retired_references].detail).to include("4000->1056")
  end
end

RSpec.describe Untded::OcrSampler do
  it "re-reads sampled rows from the page images and agrees on names" do
    results = described_class.new(pdf: source_pdf, data_dir: data_dir, sample_size: 8).call
    names = results.select { |r| r.field == "name" }
    expect(names.size).to eq(8)
    expect(names.count(&:pass)).to be >= 7
  end
end
