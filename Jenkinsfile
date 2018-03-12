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
          '''
      }
    }

    stage('Database') {
      steps {
        sh '''#!/bin/bash -le
          dropdb i18nlite_test
          createdb i18nlite_test
          '''
      }
    }

    stage('Tests') {
      steps {
        sh '''#!/bin/bash -le
          bundle exec rspec
          '''
      }
    }
  }
}

