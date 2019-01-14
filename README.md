# i18nlite

## Dependencies

https://github.com/thoughtbot/appraisal

```
bundle exec appraisal install
```

## Testing

The test scripts requires a Postgres connection, and a test database. Before running the tests the first time, do
```bash
psql < spec/support/init_test_db.sql
```
as a user with ```login``` and ```createdb``` priviliges.

## Releasing

<https://docs.promoteapp.net/promote/development/private-ruby-gem-server.html#publish>

