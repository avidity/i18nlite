require 'i18nlite'

namespace :i18nlite do
  desc "Syncronise YAML translations with the database"
  task :sync => :environment do
    importer = I18nLite::Importer::SimpleBackend.new(:en)
    importer.sync!
  end

  desc "Imports YAML translations that does not exist in database"
  task :import => :environment do
    importer = I18nLite::Importer::SimpleBackend.new(:en)
    importer.import!
  end

  desc "Removes translations for keys that does not exist in system locale"
  task :trim_keys => :environment do
    PromoteTranslation.trim_to_universe(I18n.system_locale)
  end
end

