#!groovy

pipeline {
  agent any

  environment {
    I18NLITE_DB_USER = ""
    I18NLITE_DB_PASS = ""
  }

  stages {
    stage('Dependencies') {
      steps {
        sh '''#!/bin/bash -le
          bundle --jobs 4
          bundle exec appraisal install
          '''
      }
    }

    stage('Database') {
      steps {
        sh '''#!/bin/bash -le
          dropdb i18nlite_test --if-exists
          createdb i18nlite_test
          '''
      }
    }

    stage('Tests') {
      steps {
        sh '''#!/bin/bash -le
          bundle exec appraisal rspec
          '''
      }
    }

    stage('Trigger gem deploy') {
      when {
        buildingTag()
      }
      steps {
        sh '''#!/bin/bash -le
          export BUILD_VERSION=$(bundle exec ruby -e 'puts I18nLite::VERSION')
          test "v$BUILD_VERSION" = "$TAG_NAME"
          gem build i18nlite.gemspec
          gem push --host https://gems.promoteapp.net/private i18nlite-$BUILD_VERSION.gem --key push_api_key
          '''
      }
    }
  }
}
