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
        GOPATH = "${env.WORKSPACE}/git"
        AISPHERE = "${env.GOPATH}/src/github.com/AISphere"
        PROTOC_ZIP = "protoc-3.6.1-linux-x86_64.zip"
        DOCKER_NAMESPACE = "dlaas_dev"
        DOCKER_REPO_NAME="${env.JOB_NAME}".substring("AI-Sphere2/".length(), "${env.JOB_NAME}".length() - "${env.BRANCH_NAME}".length() - 1)
        DOCKER_IMG_NAME = "${env.DOCKER_REPO_NAME}"
        DOCKERHUB_CREDENTIALS_ID = "bluemix-cr-ng"
        DOCKERHUB_HOST = "registry.ng.bluemix.net"
    }

    options {
        checkoutToSubdirectory("${env.AISPHERE}")
        skipDefaultCheckout()
    }

    stages {
        stage('ensure toolchain') {
            steps {
                sh "rm -rf ${env.AISPHERE}"
                sh 'printenv'

                echo "Testing docker"
                sh "docker info"

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

                echo "Testing rsync"
                sh "which rsync"

                echo "Testing go"
                sh "go version"
            }
        }
        x blah blah
        stage('git checkout') {
            steps {
                echo 'checking dependent repos out'

                sh "rm -rf ${env.AISPHERE}/git"
                script {
                    String[] repos = [
                            "ffdl-community",
                            "rest-apis",
                            "ffdl-dashboard",
                            "ffdl-model-metrics",
                            "ffdl-trainer",
                            "ffdl-lcm",
                            "ffdl-job-monitor",
                            "ffdl-commons",
                            "ffdl-e2e-test"] as String[]

                    echo "top of loop"
                    // echo repos
                    for (String repo in repos) {
                        echo "------ Considering ${repo} ------"
                        dir("${env.AISPHERE}/${repo}") {
                            if (repo == env.DOCKER_REPO_NAME) {
                                echo "====== Trying to pull ${env.BRANCH_NAME} ${repo} ======"
                                LONG_GIT_COMMIT = checkout(scm).GIT_COMMIT
                            } else {
                                echo "====== Trying to pull master ${repo} ======"
                                echo "Checking out ${repo}"
                                git branch: 'master', url: "https://github.com/AISphere/${repo}.git"
                            }
                            echo "================================="
                        }
                    }
                }
           }
        }
        stage('install deps') {
            steps {
                echo "AISPHERE is $AISPHERE"
                echo "DOCKER_REPO_NAME is $DOCKER_REPO_NAME"

                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    sh "make ensure-protoc-installed"
                    sh "make install-deps-if-needed"
                }
            }
        }
        stage('lint') {
            steps {
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    // Wait until after code reversal to do lints
                    // sh "make lint"
                    sh "make vet"
                }
            }
        }
        stage('build') {
            steps {
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    sh "make build-x86-64"
                    sh "make build-grpc-health-checker"
                }
            }
        }
        stage('docker-build') {
            steps {
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    script {
                        withEnv(["DLAAS_IMAGE_TAG=${env.JOB_BASE_NAME}-ffdl",
                                 "DOCKER_HOST_NAME=${env.DOCKERHUB_HOST}",
                                 "DOCKER_NAMESPACE=$DOCKER_NAMESPACE", "DOCKER_IMG_NAME=$DOCKER_IMG_NAME"]) {
                            echo "make docker-build"
                            sh "make docker-build"
                        }
                    }
                }
            }
        }
        stage('Unit Test') {
            steps {
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    sh "make test-unit"
                }
            }
        }
        stage('Integration Test') {
            steps {
                echo 'Integration testing is supposed be here.'
            }
        }
        stage('push') {
            steps {
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    script {
                        withDockerServer([uri: "unix:///var/run/docker.sock"]) {
                            withDockerRegistry([credentialsId: "${env.DOCKERHUB_CREDENTIALS_ID}",
                                                url: "https://registry.ng.bluemix.net"]) {
                                withEnv(["DLAAS_IMAGE_TAG=${env.JOB_BASE_NAME}-ffdl",
                                         "DOCKER_HOST_NAME=${env.DOCKERHUB_HOST}",
                                         "DOCKER_NAMESPACE=$DOCKER_NAMESPACE", "DOCKER_IMG_NAME=$DOCKER_IMG_NAME"]) {
                                    // sh "docker build -t \"${env.DOCKERHUB_HOST}/$DOCKER_NAMESPACE/$DOCKER_IMG_NAME:$DLAAS_IMAGE_TAG\" ."
                                    sh "make docker-push"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
