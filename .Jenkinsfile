pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 12, unit: 'HOURS')
    }

    triggers {
        // Normal SCM polling does not inspect submodule branch tips.
        cron('H/15 * * * *')
    }

    parameters {
        booleanParam(name: 'FORCE_BUILD', defaultValue: false, description: 'Build even when tracked revisions are unchanged')
        string(name: 'BUILD_DIR', defaultValue: 'jenkins-build', description: 'Persistent Yocto build directory')
        string(name: 'IMAGE', defaultValue: 'core-image-minimal', description: 'BitBake image target')
        string(name: 'MACHINE', defaultValue: '', description: 'Override MACHINE; blank uses the last MACHINE@ entry in setup.sh')
        string(name: 'BUILD_COMMAND', defaultValue: '', description: 'Optional complete build command')
        booleanParam(name: 'QEMU_TESTS', defaultValue: false, description: 'Boot with runqemu and execute runtime tests')
        string(name: 'QEMU_MACHINE', defaultValue: '', description: 'QEMU-capable MACHINE, e.g. qemu-generic-arm64')
        string(name: 'TEST_SUITES', defaultValue: 'ping ssh date df', description: 'Space-separated OEQA runtime test suites')
        string(name: 'UPSTREAM_POLL_TIMEOUT', defaultValue: '30', description: 'Seconds allowed for each remote query')
    }

    environment {
        UPSTREAM_STATE_FILE = '.jenkins-upstreams.state'
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Check upstream revisions') {
            steps {
                script {
                    int status = sh(script: ".ci/check-upstreams.sh --state '${env.UPSTREAM_STATE_FILE}' --timeout '${params.UPSTREAM_POLL_TIMEOUT}'", returnStatus: true)
                    if (status == 0) {
                        env.SHOULD_BUILD = 'true'
                    } else if (status == 3 && params.FORCE_BUILD) {
                        sh 'cp "$UPSTREAM_STATE_FILE" "${UPSTREAM_STATE_FILE}.pending"'
                        env.SHOULD_BUILD = 'true'
                    } else if (status == 3) {
                        env.SHOULD_BUILD = 'false'
                        currentBuild.description = 'No upstream changes'
                        currentBuild.result = 'NOT_BUILT'
                    } else {
                        error("Unable to inspect upstream repositories (exit ${status})")
                    }
                }
            }
        }

        stage('Update submodules') {
            when { expression { env.SHOULD_BUILD == 'true' } }
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail
                    git submodule sync --recursive
                    git submodule update --init --recursive --remote --jobs 8
                '''
            }
        }

        stage('Build and test') {
            when { expression { env.SHOULD_BUILD == 'true' } }
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail
                    if [[ -n "${BUILD_COMMAND:-}" ]]; then
                        bash -lc "$BUILD_COMMAND"
                    else
                        .ci/jenkins-build.sh
                    fi
                '''
            }
        }

        stage('Record successful revisions') {
            when { expression { env.SHOULD_BUILD == 'true' } }
            steps {
                sh 'mv "${UPSTREAM_STATE_FILE}.pending" "$UPSTREAM_STATE_FILE"'
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: "${params.BUILD_DIR}/tmp/log/**/*,${params.BUILD_DIR}/tmp/testimage/**/*", allowEmptyArchive: true
            junit testResults: "${params.BUILD_DIR}/tmp/log/oeqa/**/*.xml,${params.BUILD_DIR}/tmp/testimage/**/*.xml", allowEmptyResults: true
        }
    }
}
