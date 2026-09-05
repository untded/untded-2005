require "spec_helper"

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
    expect(graph["@graph"].size).to eq(1505)
    dataset = by_id["https://example.untded.test/dataset/untded-2005"]
    expect(dataset["@type"]).to eq("Dataset")
    expect(dataset["elementCount"]).to eq(1504)
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
