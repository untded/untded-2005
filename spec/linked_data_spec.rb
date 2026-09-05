require "spec_helper"
require "tmpdir"

RSpec.describe Untded::LinkedData do
  let(:elements) do
    Dir.glob(File.join(data_dir, "elements", "*.yaml")).sort.flat_map do |path|
      Untded::ElementFile.from_yaml(File.read(path)).elements
    end
  end
  subject(:linked) { described_class.new(elements: elements, origin: "https://example.untded.test") }

  let(:graph) { linked.graph }
  let(:by_id) { graph["@graph"].to_h { |n| [n["@id"], n] } }

  it "carries the YAML-LD context from vocab/" do
    expect(graph["@context"]).to include(
      "utd" => "https://www.untded.org/ns/untded#",
      "TradeDataElement" => "utd:TradeDataElement",
    )
  end

  it "emits one dataset node and one node per element" do
    expect(graph["@graph"].size).to eq(1533)
    dataset = by_id["https://example.untded.test/dataset/untded-2005"]
    expect(dataset["@type"]).to eq("Dataset")
    expect(dataset["elementCount"]).to eq(1504)
  end

  it "models categories as resources with belonging relations" do
    cats = graph["@graph"].select { |n| n["@type"] == "Category" }
    expect(cats.size).to eq(9)
    first = by_id["https://example.untded.test/categories/1000-1699"]
    expect(first).to include("tagRange" => "1000-1699", "position" => 1, "elementCount" => 144)
    expect(first["inScheme"]["@id"]).to end_with("CategoryScheme")
    expect(by_id["https://example.untded.test/elements/1001"]["category"]["@id"]).to eq("https://example.untded.test/categories/1000-1699")
  end

  it "declares the vocabulary classes and properties" do
    defs = graph["@graph"]
    expect(defs.count { |n| n["@type"] == "rdfs:Class" }).to eq(3)
    expect(defs.count { |n| n["@type"] == "rdf:Property" }).to eq(15)
    expect(by_id["https://www.untded.org/ns/untded#tag"]["domain"]["@id"]).to end_with("TradeDataElement")
  end

  it "shapes a known element faithfully" do
    e = by_id["https://example.untded.test/elements/1001"]
    expect(e).to include(
      "@type" => "TradeDataElement",
      "tag" => 1001,
      "name" => "Document. Type.Code",
      "representation" => "an..3",
      "charset" => "an",
      "maxLength" => 3,
      "changeTag" => "cndr",
      "status" => "active",
      "oldName" => "Document/message name, coded",
      "sourcePage" => 28,
      "extractionConfidence" => "medium",
    )
  end

  it "round-trips JSON-LD and Turtle through the RDF gems" do
    require "json/ld"
    require "rdf/turtle"
    jsonld_statements = JSON::LD::API.toRdf(graph)
    expect(jsonld_statements.size).to be > 1504 * 8

    ttl = linked.to_ttl
    expect(ttl).to start_with("@prefix")
    ttl_graph = RDF::Graph.new << RDF::Turtle::Reader.new(ttl)
    expect(ttl_graph.statements.size).to eq(jsonld_statements.size)
    expect(ttl_graph.query([RDF::URI("https://example.untded.test/elements/9649"), RDF::URI("https://www.untded.org/ns/untded#tag"), nil]).objects.first.to_i).to eq(9649)
  end
end

RSpec.describe Untded::LinkedData, "#write_element_files" do
  it "writes dereferenceable JSON-LD and Turtle per element" do
    elements = Dir.glob(File.join(data_dir, "elements", "*.yaml")).sort.flat_map do |path|
      Untded::ElementFile.from_yaml(File.read(path)).elements
    end
    linked = described_class.new(elements: elements, origin: "https://example.untded.test")
    Dir.mktmpdir do |tmp|
      linked.write_element_files(tmp)
      expect(Dir.children(tmp).sort).to eq(elements.map { |e| ["#{e.tag}.jsonld", "#{e.tag}.ttl"] }.flatten.sort)
      node = JSON.parse(File.read(File.join(tmp, "1000.jsonld")))
      expect(node["@id"]).to eq("https://example.untded.test/elements/1000")
      expect(node).to include("name" => "Document. Type Name.Text", "@context" => hash_including("utd"))
      expect(File.read(File.join(tmp, "1000.ttl"))).to include("<https://example.untded.test/elements/1000> a utd:TradeDataElement")
    end
  end
end
