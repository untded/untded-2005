module Untded
  # Single declaration of the dataset's RDF vocabulary: namespace,
  # prefixes, classes and terms. The YAML-LD context
  # (vocab/untded-context.yamlld) and the ontology nodes of the Linked
  # Data graph derive from this module — nothing else declares term
  # names or IRIs.
  module Vocabulary
    NAMESPACE = "https://www.untded.org/ns/untded#"

    PREFIXES = {
      "utd" => NAMESPACE,
      "schema" => "https://schema.org/",
      "dct" => "http://purl.org/dc/terms/",
      "skos" => "http://www.w3.org/2004/02/skos/core#",
      "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
      "owl" => "http://www.w3.org/2002/07/owl#",
      "xsd" => "http://www.w3.org/2001/XMLSchema#",
    }.freeze

    # Classes of the utd: namespace, declared in the graph as rdfs:Class.
    CLASSES = {
      "TradeDataElement" =>
        "A data element of the Trade Data Elements Directory: a named, defined unit of trade information with a tag and a representation.",
      "Category" =>
        "One of the nine ordered tag ranges into which the directory groups its data elements.",
      "CategoryScheme" =>
        "The ordered scheme of the nine tag-range categories.",
    }.freeze

    # term => declaration. group drives the generated context layout and
    # the ontology node order; iri is the context mapping; comment and
    # domain (utd: terms only) drive the ontology nodes.
    TERMS = {
      # classes used as @type values
      "TradeDataElement" => { group: "classes", iri: "utd:TradeDataElement" },
      "Category" => { group: "classes", iri: "utd:Category" },
      "CategoryScheme" => { group: "classes", iri: "utd:CategoryScheme" },
      "Dataset" => { group: "classes", iri: "schema:Dataset" },
      "DataDownload" => { group: "classes", iri: "schema:DataDownload" },

      # dataset-level
      "name" => { group: "dataset-level", iri: "schema:name" },
      "description" => { group: "dataset-level", iri: "schema:description" },
      "isPartOf" => { group: "dataset-level", iri: "schema:isPartOf" },
      "isBasedOn" => { group: "dataset-level", iri: "schema:isBasedOn" },
      "distribution" => { group: "dataset-level", iri: "schema:distribution" },
      "encodingFormat" => { group: "dataset-level", iri: "schema:encodingFormat" },
      "source" => { group: "dataset-level", iri: "dct:source" },
      "elementCount" => { group: "dataset-level", iri: "utd:elementCount",
                          comment: "The number of member elements." },

      # element-level
      "tag" => { group: "element-level", iri: "utd:tag", domain: "TradeDataElement",
                 comment: "The four-digit unique identifier of the data element." },
      "representation" => { group: "element-level", iri: "utd:representation", domain: "TradeDataElement",
                            comment: "The printed character representation notation, e.g. an..35." },
      "charset" => { group: "element-level", iri: "utd:charset", domain: "TradeDataElement",
                     comment: "The character class of the representation: a, an or n." },
      "minLength" => { group: "element-level", iri: "utd:minLength", domain: "TradeDataElement",
                       comment: "Minimum number of characters in a value." },
      "maxLength" => { group: "element-level", iri: "utd:maxLength", domain: "TradeDataElement",
                       comment: "Maximum number of characters in a value." },
      "changeTag" => { group: "element-level", iri: "utd:changeTag", domain: "TradeDataElement",
                       comment: "The printed change indicator against the 1993 edition." },
      "status" => { group: "element-level", iri: "utd:status", domain: "TradeDataElement",
                    comment: "active or retired, per the printed change indicator." },
      "oldName" => { group: "element-level", iri: "utd:oldName", domain: "TradeDataElement",
                     comment: "The data element name in the 1993 edition." },
      "businessTerm" => { group: "element-level", iri: "utd:businessTerm", domain: "TradeDataElement",
                          comment: "The printed business term (synonym)." },
      "bridges" => { group: "element-level", iri: "utd:bridges", domain: "TradeDataElement",
                     comment: "Printed locations on aligned trade documents (UNLK, SAD, CIMP, CIM, MAR)." },
      "sourcePage" => { group: "element-level", iri: "utd:sourcePage", domain: "TradeDataElement",
                        comment: "Page of the source publication the entry appears on." },
      "category" => { group: "element-level", iri: "utd:category", domain: "TradeDataElement",
                      comment: "The tag-range category the element belongs to." },

      # category-level
      "tagRange" => { group: "category-level", iri: "utd:tagRange", domain: "Category",
                      comment: "The tag interval of the category, e.g. 1000-1699." },
      "position" => { group: "category-level", iri: "schema:position" },
      "member" => { group: "category-level", iri: "skos:member" },
      "inScheme" => { group: "category-level", iri: "skos:inScheme" },

      # vocabulary definitions
      "label" => { group: "vocabulary definitions", iri: "rdfs:label" },
      "comment" => { group: "vocabulary definitions", iri: "rdfs:comment" },
      "domain" => { group: "vocabulary definitions", iri: "rdfs:domain" },
      "range" => { group: "vocabulary definitions", iri: "rdfs:range" },
      "subClassOf" => { group: "vocabulary definitions", iri: "rdfs:subClassOf" },
    }.freeze

    ONTOLOGY_GROUP_ORDER = %w[element-level category-level dataset-level].freeze

    def self.context
      PREFIXES.merge(TERMS.to_h { |term, defn| [term, defn[:iri]] })
    end

    def self.ontology_nodes
      ns = NAMESPACE
      class_nodes = CLASSES.map do |name, comment|
        { "@id" => "#{ns}#{name}", "@type" => "rdfs:Class", "comment" => comment }
      end
      prop_nodes = TERMS.select { |_, defn| ONTOLOGY_GROUP_ORDER.include?(defn[:group]) }
                         .filter_map do |term, defn|
        next unless defn[:comment]
        node = { "@id" => "#{ns}#{term}", "@type" => "rdf:Property", "comment" => defn[:comment] }
        node["domain"] = { "@id" => "#{ns}#{defn[:domain]}" } if defn[:domain] && CLASSES.key?(defn[:domain])
        node
      end
      class_nodes + prop_nodes
    end
  end
end
