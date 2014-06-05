require 'i18nlite'

namespace :i18n do
  desc "Alias of i18nlite:sync"
  task :import => :environment do
    delegate_task = ['i18nlite:sync', 'app:i18nlite:sync'].find { |t|
      Rake::Task.task_defined?(t)
    }

    if delegate_task.nil?
      raise "Cannot find suitable i18nlite task, is it installed?"
    else
     Rake::Task[delegate_task].invoke
    end
  end
end
