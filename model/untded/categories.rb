module Untded
  # The nine tag-range categories of section 4.2, declared once in
  # structured form. Everything category-shaped derives from here: the
  # YAML file headers written by the Extractor, the Linked Data category
  # nodes, and the categories.json export consumed by the website.
  # Labels are the source's own section titles, verbatim.
  module Categories
    ALL = [
      { k: 1, section: "4.2.1", range: "1000-1699", label: "documentation, references" },
      { k: 2, section: "4.2.2", range: "2000-2699", label: "Dates, times, periods of time" },
      { k: 3, section: "4.2.3", range: "3000-3699", label: "Parties, addresses, places, countries" },
      { k: 4, section: "4.2.4", range: "4000-4699", label: "Clauses, conditions, terms, instructions" },
      { k: 5, section: "4.2.5", range: "5000-5699", label: "Amounts, charges, percentages" },
      { k: 6, section: "4.2.6", range: "6000-6699", label: "Measure identifiers, quantities (other than monetary)" },
      { k: 7, section: "4.2.7", range: "7000-7699", label: "Goods and articles: descriptions and identifiers" },
      { k: 8, section: "4.2.8", range: "8000-8699", label: "Transport modes, means and equipments" },
      { k: 9, section: "4.2.9", range: "9000-9699", label: "Other data elements (Customs, etc.)" },
    ].freeze

    # The category whose tag range starts at the given base, e.g. "1000".
    def self.for_base(base)
      ALL.find { |c| c[:range].start_with?("#{base}-") }
    end

    # The YAML file header string for a category, e.g.
    # "4.2.1 (1000-1699) documentation, references".
    def self.header(c)
      "#{c[:section]} (#{c[:range]}) #{c[:label]}"
    end
  end
end
