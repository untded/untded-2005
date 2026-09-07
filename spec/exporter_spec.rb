require "spec_helper"
require "tmpdir"
require "json"
require "csv"

RSpec.describe Untded::Exporter do
  it "writes all artifacts from the real corpus" do
    Dir.mktmpdir do |tmp|
      count = described_class.new(data_dir, tmp).call
      expect(count).to eq(1504)

      # all artifacts written
      %w[elements.csv elements.json categories.json vocabulary.json parser-fixtures.json].each do |f|
        expect(File.exist?(File.join(tmp, f))).to be_truthy, "missing #{f}"
      end

      # CSV: one row per element + header
      rows = CSV.read(File.join(tmp, "elements.csv"))
      expect(rows.length).to eq(1505) # header + 1504

      # JSON: full records
      data = JSON.parse(File.read(File.join(tmp, "elements.json")))
      expect(data["elements"].length).to eq(1504)

      # categories: nine
      cats = JSON.parse(File.read(File.join(tmp, "categories.json")))
      expect(cats.length).to eq(9)

      # vocabulary: the declaration shape
      vocab = JSON.parse(File.read(File.join(tmp, "vocabulary.json")))
      expect(vocab["namespace"]).to include("untded#")
      expect(vocab["classes"]).not_to be_empty
      expect(vocab["terms"]).not_to be_empty

      # parser fixtures: the seven edge cases
      fixtures = JSON.parse(File.read(File.join(tmp, "parser-fixtures.json")))
      expect(fixtures["cases"].map { |c| c["tag"] }.sort).to eq([1002, 1004, 1082, 1128, 1188, 2025, 5010])
    end
  end
end
