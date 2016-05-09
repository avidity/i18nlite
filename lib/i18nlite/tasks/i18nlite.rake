namespace :i18nlite do

  def importer
    I18nLite::Importer::SimpleBackend.new(
      translation_model: I18n.backend.model,
      locale_model: I18n.backend.locale_model,
      source_locale: :en
    )
  end

  desc "Syncronise YAML translations with the database"
  task :sync => :environment do
    num = importer.sync!

    puts "Refreshed #{num} translations (#{importer.target_locale})"
  end

  desc "Imports YAML translations that does not exist in database"
  task :import => :environment do
    num = importer.import!

    puts "Inserted #{num} new translations"
  end

  desc "Removes translations for keys that does not exist in system locale"
  task :trim_keys => :environment do
    I18n.backend.model.trim_to_universe(I18n.system_locale)

    puts "Removed disused translations in all locales"
  end

  desc 'Clears current translation cache'
  task :clear_cache => :environment do
    I18nLite::CacheControl.clear_all

    puts "Cleared translation cache"
  end
end
