#!groovy
pipeline {
    agent {
        docker {
            image 'ffdl/ffdlbuildtools:v1'
            alwaysPull true
            reuseNode false
        }
    }
    environment {
        GOPATH = "${env.JENKINS_HOME}/workspace/git"
        AISPHERE = "${env.JENKINS_HOME}/workspace/git/src/github.com/AISphere"
        PROTOC_ZIP = "protoc-3.6.1-linux-x86_64.zip"
        // registry = "docker_hub_account/repository_name"
        // registryCredential = 'dockerhub'
        DOCKER_NAMESPACE = "dlaas_dev"
        DOCKER_IMG_NAME = "ffdl-trainer"
        DOCKERHUB_CREDENTIALS_ID = "bluemix-cr-ng"
        DOCKERHUB_HOST = "registry.ng.bluemix.net"
    }

    options {
        checkoutToSubdirectory("/var/jenkins_home/workspace/git/src/github.com/AISphere")
        skipDefaultCheckout()
    }

    stages {
        stage('ensure toolchain') {
            steps {
                dir("$AISPHERE") {
                    echo "Testing docker"
                    sh "docker info"

                    echo "Testing env from shell"
                    sh "env"

                    echo "Testing echo from shell"
                    sh 'echo "hello"'

                    echo "Testing zip"
                    sh "which zip"

                    echo "Testing protoc"
                    sh "which protoc"

                    echo "Testing protoc-gen-go"
                    sh "which protoc-gen-go"

                    echo "Testing kubectl"
                    sh "which kubectl"

                    echo "Testing glide"
                    sh "which glide"

                    echo "Testing go"
                    sh "go version"
                }
            }
        }
        stage('git checkout') {
            steps {
                echo 'checking dependent repos out'

                sh "rm -rf ${env.AISPHERE}/git"

                // Note: I tried to get the names of these dynamically and get the repos in
                // a loop, but it got too tricky and this is good for now.
                dir("$AISPHERE/ffdl-community") {
                    echo "Checking out ffdl-community"
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-community.git'
                }
                dir("$AISPHERE/rest-apis") {
                    echo "Checking out rest-apis"
                    git branch: 'master', url: 'https://github.com/AISphere/rest-apis.git'
                }
                dir("$AISPHERE/ffdl-dashboard") {
                    echo "Checking out ffdl-dashboard"
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-dashboard.git'
                }
                dir("$AISPHERE/ffdl-model-metrics") {
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-model-metrics.git'
                }
                dir("$AISPHERE/ffdl-lcm") {
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-lcm.git'
                }
                dir("$AISPHERE/ffdl-job-monitor") {
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-job-monitor.git'
                }
                dir("$AISPHERE/ffdl-commons") {
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-commons.git'
                }
                dir("$AISPHERE/ffdl-e2e-test") {
                    git branch: 'master', url: 'https://github.com/AISphere/ffdl-e2e-test.git'
                }
                dir("$AISPHERE/ffdl-trainer") {
                    sh 'printenv'
                    echo "================================="
                    echo "=== Trying to pull PR ==="
                    echo "GIT_BRANCH: ${env.GIT_BRANCH}"
                    echo "GIT_COMMIT: ${env.GIT_COMMIT}"
                    echo "CHANGE_ID: ${env.CHANGE_ID}"

                    checkout([$class: 'GitSCM', branches: [[name: "FETCH_HEAD"]],
                              extensions: [[$class: 'LocalBranch']],
                              userRemoteConfigs: [
                                      [refspec: "+refs/pull/${env.CHANGE_ID}/head:refs/remotes/origin/PR-${env.CHANGE_ID}",
                                       url: "https://github.com/AISphere/ffdl-trainer.git"]]])

                    echo "================================="
                }
            }
        }
        stage('install deps') {
            steps {
                dir("$AISPHERE/ffdl-trainer") {
                    sh "make ensure-protoc-installed"
                    sh "make install-deps-if-needed"
                }
            }
        }
        stage('build') {
            steps {
                dir("$AISPHERE/ffdl-trainer") {
                    sh "make build-x86-64"
                    sh "make build-grpc-health-checker"
                }
            }
        }
        stage('docker-build') {
            steps {
                dir("$AISPHERE/ffdl-trainer") {
                    script {
                        withDockerServer([uri: "unix:///var/run/docker.sock"]) {
                            withDockerRegistry([credentialsId: "${env.DOCKERHUB_CREDENTIALS_ID}",
                                                url: "https://registry.ng.bluemix.net"]) {
                                withEnv(["DLAAS_IMAGE_TAG=${env.JOB_BASE_NAME}"]) {
                                    sh "docker build -t \"${env.DOCKERHUB_HOST}/$DOCKER_NAMESPACE/$DOCKER_IMG_NAME:$DLAAS_IMAGE_TAG\" ."
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('Unit Test') {
            steps {
                dir("$AISPHERE/ffdl-trainer") {
                    sh "make test-unit"
                }
            }
        }
        stage('Integration Test') {
            steps {
                echo 'Integration testing for the fun of it..'
            }
        }
        stage('push') {
            steps {
                dir("$AISPHERE/ffdl-trainer") {
                    script {
                        withDockerServer([uri: "unix:///var/run/docker.sock"]) {
                            withDockerRegistry([credentialsId: "${env.DOCKERHUB_CREDENTIALS_ID}",
                                                url: "https://registry.ng.bluemix.net"]) {
                                withEnv(["DLAAS_IMAGE_TAG=${env.JOB_BASE_NAME}"]) {
                                    sh "docker push \"${env.DOCKERHUB_HOST}/$DOCKER_NAMESPACE/$DOCKER_IMG_NAME:$DLAAS_IMAGE_TAG\""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
