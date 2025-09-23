FROM ruby:3.3.2

ENV RAILS_VERSION 6.0.1
ENV I18NLITE_DB_NAME i18nlite_test

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev postgresql-client

RUN mkdir /i18nlite 
WORKDIR /i18nlite

COPY . /i18nlite

RUN bundle install && \
    bundle exec appraisal generate && \
    bundle exec appraisal install

CMD ["bundle", "exec", "appraisal", "rspec"]
