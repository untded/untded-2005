$LOAD_PATH.unshift File.expand_path("../model", __dir__)
require "untded"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def project_root
  File.expand_path("..", __dir__)
end

def data_dir
  File.join(project_root, "data")
end

def source_pdf
  File.join(ENV.fetch("UNTDED_REFERENCES_DIR", File.join(project_root, "..", "references")), "UNTDED2005_Redacted.pdf")
end
