// Jenkinsfile — iOSNetworkContract (iOS) · pipeline de release manual.
//
// Dispara con el botón "Build with Parameters" en Jenkins, eligiendo el bump.
// Genera el xcframework, lo sube al storage interno, y crea el git tag.
//
// Requisitos en el agente (confirmar con DevOps):
//   - macOS con Xcode (label del agente: ajustar 'ios')
//   - Ruby + Bundler (para Fastlane)
//   - Credenciales de Artifactory (Jenkins credentials)
//   - Acceso de push al repo (para tag)

pipeline {
    agent { label 'ios' }   // TODO DevOps: label real del agente macOS con Xcode

    parameters {
        choice(
            name: 'BUMP',
            choices: ['patch', 'minor', 'major'],
            description: 'Tipo de incremento semver para el tag de release'
        )
    }

    options {
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30'))
        disableConcurrentBuilds()
    }

    environment {
        // TODO DevOps: URL base del storage donde se publican los binarios iOS.
        IOSNETWORKCONTRACT_ARTIFACT_BASE_URL = 'https://STORAGE-A-DEFINIR.scotiabank.cl/ios/iOSNetworkContract'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install deps') {
            steps {
                sh '''
                    bundle config set --local path 'vendor/bundle'
                    bundle install --jobs 4
                '''
            }
        }

        stage('Test') {
            steps {
                sh 'bundle exec fastlane test'
            }
        }

        stage('Release') {
            steps {
                // TODO DevOps: ajustar credentialsId al de Artifactory.
                withCredentials([usernamePassword(
                    credentialsId: 'artifactory-ios',
                    usernameVariable: 'ART_USER',
                    passwordVariable: 'ART_TOKEN'
                )]) {
                    sh "bundle exec fastlane release bump:${params.BUMP}"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Release ${params.BUMP} completado."
        }
        failure {
            echo "❌ Release falló. Revisar logs."
        }
        always {
            cleanWs()
        }
    }
}
