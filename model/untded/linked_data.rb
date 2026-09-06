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
      Vocabulary.context
    end

    def dataset_iri
      "#{origin}/dataset/untded-2005"
    end

    def scheme_iri
      "#{origin}/ns/untded#CategoryScheme"
    end

    def category_iri(c)
      "#{origin}/categories/#{c[:range]}"
    end

    def graph
      {
        "@context" => context,
        "@graph" =>
          Vocabulary.ontology_nodes + [dataset_node, scheme_node] +
          categories.map { |c| category_node(c) } +
          @elements.map { |e| element_node(e) },
      }
    end

    def to_jsonld
      JSON.pretty_generate(graph)
    end

    def to_ttl
      require "rdf/turtle"
      require "json/ld"
      statements = JSON::LD::API.toRdf(graph)
      RDF::Graph.new.insert(*statements).dump(:ttl, prefixes: ttl_prefixes, base: "#{origin}/")
    end

    # Per-element dereferenceable files: for each element IRI, a standalone
    # JSON-LD document and a Turtle serialization of just that element's
    # statements. The registry serves these at /elements/<tag>/data.*.
    def write_element_files(dir)
      require "fileutils"
      require "rdf/turtle"
      require "json/ld"
      FileUtils.mkdir_p(dir)
      statements = JSON::LD::API.toRdf(graph).group_by(&:subject)
      @elements.each do |e|
        iri = RDF::URI("#{origin}/elements/#{e.tag}")
        node = element_node(e)
        File.write(File.join(dir, "#{e.tag}.jsonld"),
          JSON.pretty_generate({ "@context" => context }.merge(node)))
        sub = RDF::Graph.new.insert(*(statements[iri] || []))
        File.write(File.join(dir, "#{e.tag}.ttl"),
          sub.dump(:ttl, prefixes: ttl_prefixes, base: "#{origin}/"))
      end
    end

    private

    def dataset_node
      {
        "@id" => dataset_iri,
        "@type" => "Dataset",
        "name" => "UNTDED 2005 — United Nations Trade Data Elements Directory",
        "description" => "1504 trade data elements of the 2005 edition " \
          "(ECE/TRADE/362, ISO 7372:2005). " \
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

    def scheme_node
      {
        "@id" => scheme_iri,
        "@type" => "CategoryScheme",
        "label" => "UNTDED tag-range category scheme",
        "comment" => "The nine ordered tag ranges of the Trade Data Elements Directory (TDED section 4.2).",
      }
    end

    # Structured category records (Untded::CATEGORIES) with display-
    # capitalised labels; the single category source for the graph.
    def categories
      @categories ||= Untded::Categories::ALL.map do |c|
        { k: c[:k], section: c[:section], range: c[:range],
          label: c[:label][0].upcase + c[:label][1..] }
      end
    end

    def category_of_tag(tag)
      categories.find { |c| c[:k] == tag / 1000 }
    end

    def category_node(c)
      in_range = @elements.select { |e| (e.tag / 1000) == c[:k] }
      {
        "@id" => category_iri(c),
        "@type" => "Category",
        "label" => c[:label],
        "tagRange" => c[:range],
        "position" => c[:k],
        "inScheme" => { "@id" => scheme_iri },
        "isPartOf" => { "@id" => dataset_iri },
        "elementCount" => in_range.size,
      }
    end
    # Self-describing vocabulary: the classes and properties of the utd:
    # namespace, declared once in Untded::Vocabulary.
    def element_node(e)
      category = category_of_tag(e.tag)
      node = {
        "@id" => "#{origin}/elements/#{e.tag}",
        "@type" => "TradeDataElement",
        "tag" => e.tag,
        "isPartOf" => { "@id" => dataset_iri },
        "category" => { "@id" => category_iri(category) },
        "changeTag" => e.change_tag,
        "status" => e.status,
        "sourcePage" => e.provenance.page,
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
      # the vocabulary namespace is minted once in Untded::Vocabulary and
      # is independent of the deployment origin
      Vocabulary::PREFIXES
    end
  end
end
