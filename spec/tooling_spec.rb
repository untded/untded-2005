require "spec_helper"
require "tmpdir"

RSpec.describe Untded::Validator do
  subject(:result) { described_class.new(data_dir).call }

  it "reports no errors on the real data" do
    expect(result.errors).to be_empty
  end

  it "counts the full directory" do
    expect(result.summary[:elements]).to eq(1504)
    expect(result.summary[:files]).to eq(9)
    expect(result.summary[:active] + result.summary[:retired]).to eq(1504)
  end
end

RSpec.describe Untded::Exporter do
  let(:out1) { Dir.mktmpdir }
  let(:out2) { Dir.mktmpdir }

  it "regenerates byte-identical derived outputs" do
    count = described_class.new(data_dir, out1).call
    expect(count).to eq(1504)
    described_class.new(data_dir, out2).call

    %w[elements.csv elements.json categories.json].each do |name|
      expect(File.binread(File.join(out1, name))).to eq(File.binread(File.join(out2, name)))
    end
  end

  it "exports one CSV row per element plus a header" do
    described_class.new(data_dir, out1).call
    lines = File.readlines(File.join(out1, "elements.csv"))
    expect(lines.size).to eq(1505)
  end
end

RSpec.describe "context.jsonld export" do
  it "is the JSON form of the single context declaration" do
    require "json"
    require "tmpdir"
    Dir.mktmpdir do |tmp|
      Untded::Exporter.new(data_dir, tmp).call
      json = JSON.parse(File.read(File.join(tmp, "context.jsonld")))
      expect(json).to eq(Untded::Vocabulary.context)
    end
  end
end
