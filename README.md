# i18nlite


## Testing

The test scripts requires a Postgres connection, and a test database. Before running the tests the first time, do
```bash
psql < spec/support/init_test_db.sql
```
as a user with ```login``` and ```createdb``` priviliges.

