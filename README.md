# i18nlite

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


## Releasing

<https://docs.promoteapp.net/promote/development/private-ruby-gem-server.html#publish>

