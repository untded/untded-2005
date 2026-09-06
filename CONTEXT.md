# CONTEXT — domain glossary

Terms used across this repository and the website
(`untded/untded.github.io`). The domain is the **United Nations Trade
Data Elements Directory (UNTDED/TDED), 2005 edition** (ECE/TRADE/362,
in parallel ISO 7372:2005).

- **Element (Trade Data Element)** — one named, defined unit of trade
  information as printed in section 4.2: number, name, description,
  representation, business term, bridges, change indicator. 1504 in
  this edition. Model: `Untded::Element`; YAML: one file per category.
- **Tag** — the element's four-digit unique identifier (1000–9649). The
  lookup key; stable across editions for unchanged elements.
- **Category** — one of the nine ordered tag ranges of section 4.2
  (1000–1699 … 9000–9699). Declared once, structured, in
  `model/untded/categories.rb` (`Untded::CATEGORIES`); exported as
  `derived/categories.json` for the website.
- **Change tag** — the printed change indicator against the 1993
  edition (`add`, `cn`, `cnd`, `cnr`, `cndr`, `u`, `x`; `cd`/`cr`/`cdr`
  occur outside the printed legend). Legend: `Extractor::LEGEND_TAGS`.
- **Representation** — the printed value notation, e.g. `an..35`
  (charset, minimum/maximum length). Model: `Untded::Representation`.
- **Business term** — the printed synonym of an element name.
- **Bridges** — printed locations of the element on aligned trade
  documents (UNLK, SAD, CIMP, CIM, MAR).
- **Source page** — the page of ECE/TRADE/362 the entry appears on
  (28–132); the only per-element provenance carried in the public data.
- **Edition** — a published revision of the directory (1993, 2005).
  Scope of this repository: 2005 only.
- **Review queue** — extraction-time review entries for cells that
  needed human judgement (`data/review-queue.yaml`); internal tooling.
- **Vocabulary** — the RDF vocabulary of the dataset (prefixes,
  classes, terms), declared once in `model/untded/vocabulary.rb`
  (`Untded::Vocabulary`). The YAML-LD context and the ontology nodes in
  the graph are derived from it; a spec enforces the derivation.
- **Closure (self-description)** — the graph invariant that every used
  `utd:` term is declared in the graph itself (rdf:Property/rdfs:Class).
  Asserted in `spec/linked_data_spec.rb` and on the website.
