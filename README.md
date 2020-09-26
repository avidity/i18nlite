# i18nlite

![ruby](https://img.shields.io/badge/ruby-2.7.1-ruby.svg?colorA=99004d&colorB=cc0066)
[![MIT license](https://img.shields.io/badge/license-MIT-mit.svg?colorA=1f7a1f&colorB=2aa22a)](http://opensource.org/licenses/MIT)

I18nLite is a non-invasive, SQL driven I18n-extension for Rails.
It allows you to improve the memory usage by storing the translations in the database, querying only the ones being used and keeping them in cache for better performance. 

With i18nlite you don't have to create several translation files because you only have a few different values. I18nlite creates a list of fallbacks that allows the user to declare where the translation should be searched for first. Whenever it doesn't exist, it looks for the next file in line.

## Practical example

Although USA and UK both have english as their native language, there are enough differences between their two versions. 
Using i18nlite you would have one main file with translations common to all, and two files with translations that are different. 

```
# en.yml
...
buy_food: "Buy food!"
payment: "Payment"
...
```

```
# en-usa.yml
eat_somewhere_else: "Takeout"
```

```
# en-uk.yml
eat_somewhere_else: "Takeaway"
```

## Install

Add the following line to your Gemfile:

```ruby
gem 'i18nlite'
```

And run `bundle install` from your shell.

## Dependencies

https://github.com/thoughtbot/appraisal

```
bundle exec appraisal install
```

## Docker environment

This environment creates and runs all needed scripts to provide a running test environment. On running the container, it'll execute the tests against all the rails version listed on `./Appraisals`.

The environment provides a Postgres database to develop and test the gem.

### Running i18nlite

This command will execute the RSpec tests for every supported rails version.

```bash
docker-compose up i18nlite
```

### Accessing i18nlite container

This command will create, in the container, a development bash terminal.

```bash
docker-compose run i18nlite bash
```

## Testing

If you're not using docker environment:

- You'll need to provide a Postgres connection and a test database because this is required by the tests. The database connection information must be setted in `spec/active_record_helper.rb`.

- Before running the tests for the first time, you'll need to execute the helper SQL script it will create an user with `login` and `createdb` privileges:

```bash
psql < spec/support/init_test_db.sql
```

To execute the RSpec tests you need to:

```bash
bundle exec appraisal RSpec
```

## Common Commands

### Sync

i18nlite doesn't support dynamic translations, after creating a new key or modifying a value you'll need to sync the database.

```bash
bundle exec rake i18nlite:sync
```

### Clear cache

Sometimes it's necessary to clear the cache before synchronizing the translations:

```bash
bundle exec rake i18nlite:clear_cache
```

## Releasing

<https://docs.promoteapp.net/promote/development/private-ruby-gem-server.html#publish>

## License

i18nlite is Copyright © 2014 Avidity. It is free software, and may be redistributed under the terms specified in the [LICENSE](https://github.com/avidity/i18nlite/blob/master/LICENSE) file.
