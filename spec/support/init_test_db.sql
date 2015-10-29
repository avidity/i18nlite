-- Creates role and database for i18nlite tests

CREATE ROLE i18nlite_test WITH LOGIN CREATEDB PASSWORD 'i18nlite_test';
\c template1 i18nlite_test
CREATE DATABASE i18nlite_test;
