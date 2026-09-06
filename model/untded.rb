require "lutaml/model"

module Untded
  # Path of the working-copy PDF the pipeline extracts from: the
  # UNTDED_PDF environment variable, else the sibling references repo.
  def self.source_pdf
    ENV["UNTDED_PDF"] ||
      File.expand_path(File.join(__dir__, "..", "..", "references", "UNTDED2005_Redacted.pdf"))
  end
  autoload :Categories, "untded/categories"
  autoload :Provenance, "untded/provenance"
  autoload :Representation, "untded/representation"
  autoload :Element, "untded/element"
  autoload :ElementFile, "untded/element_file"
  autoload :ReviewEntry, "untded/review_entry"
  autoload :ReviewQueue, "untded/review_queue"
  autoload :Extractor, "untded/extractor"
  autoload :Validator, "untded/validator"
  autoload :Exporter, "untded/exporter"
  autoload :Verifier, "untded/verifier"
  autoload :OcrSampler, "untded/ocr_sampler"
  autoload :Bridges, "untded/bridges"
  autoload :UnlkZones, "untded/unlk_zones"
  autoload :Replacement, "untded/replacement"
  autoload :EdifactJoin, "untded/edifact_join"
  autoload :UnclCoverage, "untded/uncl_coverage"
  autoload :LinkedData, "untded/linked_data"
  autoload :Vocabulary, "untded/vocabulary"
end
