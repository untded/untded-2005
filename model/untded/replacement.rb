module Untded
  # The printed pointer on retired entries, e.g. "DE to use instead -
  # 1000": the element to use instead. Guards against false positives
  # (years look like tags); same rules as the website's card pointer.
  module Replacement
    def self.of(element, tags)
      return nil unless element.status == "retired" && element.notes
      element.notes.scan(/\b\d{4}\b/).map(&:to_i)
        .reject { |n| n == element.tag || n <= 699 || (n >= 1970 && n <= 2099) }
        .find { |n| tags.include?(n) }
    end
  end
end
