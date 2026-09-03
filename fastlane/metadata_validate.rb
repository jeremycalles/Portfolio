# frozen_string_literal: true

require "pathname"

LIMITS = {
  "name.txt" => 30,
  "subtitle.txt" => 30,
  "keywords.txt" => 100,
  "promotional_text.txt" => 170,
  "description.txt" => 4000,
  "release_notes.txt" => 4000,
  "support_url.txt" => 255,
  "marketing_url.txt" => 255,
  "privacy_url.txt" => 255,
  "copyright.txt" => 255
}.freeze

module MetadataValidate
  module_function

  def run(metadata_path)
    root = Pathname(metadata_path)
    errors = []

    locales = (root.children.select(&:directory?) - [root + "default"]).map(&:basename).map(&:to_s).sort
    UI.message("Checking #{locales.size} locales under #{root}") if defined?(UI)

    locales.each do |locale|
      locale_dir = root + locale
      LIMITS.each_key do |filename|
        path = locale_dir + filename
        next unless path.exist?

        text = path.read.strip
        limit = LIMITS[filename]
        errors << "#{locale}/#{filename}: #{text.length} chars (max #{limit})" if text.length > limit
      end

      keywords_path = locale_dir + "keywords.txt"
      next unless keywords_path.exist?

      keywords = keywords_path.read.strip
      if keywords.include?(", ")
        errors << "#{locale}/keywords.txt: remove spaces after commas (Apple counts them)"
      end
    end

    default_dir = root + "default"
    if default_dir.directory?
      LIMITS.each_key do |filename|
        path = default_dir + filename
        next unless path.exist?

        text = path.read.strip
        limit = LIMITS[filename]
        errors << "default/#{filename}: #{text.length} chars (max #{limit})" if text.length > limit
      end
    end

    if errors.any?
      errors.each { |message| UI.user_error!(message) if defined?(UI) }
      raise "Metadata validation failed:\n#{errors.join("\n")}" unless defined?(UI)
    end

    UI.success("Metadata validation passed (#{locales.size} locales)") if defined?(UI)
    errors
  end
end
