require "yaml"

module Untded
  # Linked Data layer: derives JSON-LD and Turtle representations of the
  # dataset from the Element models. The context (term -> IRI mapping) is
  # the YAML-LD file in vocab/ — this class only reads it and shapes the
  # graph; RDF/Turtle serialization goes through the rdf/json-ld gems.
  class LinkedData
    DEFAULT_ORIGIN = "https://www.untded.org"

    attr_reader :origin

    def initialize(elements:, origin: DEFAULT_ORIGIN)
      @elements = elements
      @origin = origin.to_s.sub(%r{/\z}, "")
    end

    def context
      YAML.safe_load(File.read(File.join(__dir__, "..", "..", "vocab", "untded-context.yamlld")))["@context"]
    end

    def dataset_iri
      "#{origin}/dataset/untded-2005"
    end

    def graph
      {
        "@context" => context,
        "@graph" => [dataset_node] + @elements.map { |e| element_node(e) },
      }
    end

    def to_jsonld
      JSON.pretty_generate(graph)
    end

    def to_ttl
      require "rdf/turtle"
      require "json/ld"
      statements = JSON::LD::API.toRdf(graph)
      RDF::Graph.new.insert(*statements).dump(:ttl, prefixes: ttl_prefixes)
    end

    private

    def dataset_node
      {
        "@id" => dataset_iri,
        "@type" => "Dataset",
        "name" => "UNTDED 2005 — United Nations Trade Data Elements Directory",
        "description" => "1504 trade data elements of the 2005 edition " \
          "(ECE/TRADE/362, ISO 7372:2005), digitized with verifiable provenance. " \
          "Operated on behalf of UN/CEFACT (UNECE) and ISO/TC 154.",
        "source" => "ECE/TRADE/362 (ISO 7372:2005), © United Nations / UNECE, reproduced with attribution",
        "elementCount" => @elements.size,
        "distribution" => [
          download("#{origin}/data/untded.jsonld", "application/ld+json"),
          download("#{origin}/data/untded.ttl", "text/turtle"),
          download("#{origin}/data/index.json", "application/json"),
        ],
      }
    end

    def download(url, format)
      { "@type" => "DataDownload", "contentUrl" => url, "encodingFormat" => format }
    end

    def element_node(e)
      node = {
        "@id" => "#{origin}/elements/#{e.tag}",
        "@type" => "TradeDataElement",
        "tag" => e.tag,
        "isPartOf" => { "@id" => dataset_iri },
        "changeTag" => e.change_tag,
        "status" => e.status,
        "sourcePage" => e.provenance.page,
        "extractionConfidence" => e.provenance.confidence,
      }
      node["name"] = e.name if e.name
      node["description"] = e.description if e.description
      if e.representation
        node["representation"] = e.representation.raw
        node["charset"] = e.representation.charset
        node["minLength"] = e.representation.min_length
        node["maxLength"] = e.representation.max_length
      end
      node["oldName"] = e.old_name if e.old_name
      node["businessTerm"] = e.business_term if e.business_term
      node["bridges"] = e.bridges if e.bridges
      node
    end

    def ttl_prefixes
      {
        "utd" => "#{origin}/ns/untded#",
        "schema" => "https://schema.org/",
        "dct" => "http://purl.org/dc/terms/",
      }
    end
  end
end
