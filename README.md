# i18nlite

## Dependencies

https://github.com/thoughtbot/appraisal

```
bundle exec appraisal install
```

## Docker environment

This environment creates and run all needed scripts to provide a running test environment. On running the container, it'll execute the tests against all the rails version listed on `./Appraisals`.

### Running i18nlite

This command will create and up a postgres database, after that it'll execute the rspec tests for every supported rails version.

```bash
docker-compose up i18nlite
```

### Accessing i18nlite container

This command will create and up a postgres database, after that it'll provide the enviroment needed to develop and test the gem.

```bash
docker-compose run i18nlite bash
```

## Testing

If you're not using docker environment:

- You'll need to provide a Postgres connection and a test database, because this is required by the tests. The database connection information must be setted in `spec/active_record_helper.rb`.

- Before running the tests for the first time, you'll need to execute this sql script that will create an user with ```login``` and ```createdb``` priviliges:
  ```bash
  psql < spec/support/init_test_db.sql
  ```


To execute the rspec tests you need to:
```bash
bundle exec appraisal rspec
```


## Releasing

<https://docs.promoteapp.net/promote/development/private-ruby-gem-server.html#publish>

