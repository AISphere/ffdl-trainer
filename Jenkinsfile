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
        DOCKER_REPO_NAME="${env.JOB_NAME}".substring("aisphere/".length(), "${env.JOB_NAME}".length() - "${env.BRANCH_NAME}".length() - 1)
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

                echo "Testing go"
                sh "go version"
            }
        }
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
                                // If someone knows a better way to do this, please do.
                                if ("${env.BRANCH_NAME}".startsWith("PR-")) {
                                    echo "trying to checkout pr"
                                    checkout([$class           : 'GitSCM', branches: [[name: "FETCH_HEAD"]],
                                              extensions       : [[$class: 'LocalBranch']],
                                              userRemoteConfigs: [
                                                      [refspec: "+refs/pull/${env.CHANGE_ID}/head:refs/remotes/origin/PR-${env.CHANGE_ID}",
                                                       url    : "https://github.com/AISphere/${env.DOCKER_REPO_NAME}.git"]]])
                                } else {
                                    git branch: "${env.BRANCH_NAME}", url: "https://github.com/AISphere/${env.DOCKER_REPO_NAME}.git"
                                }
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
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
                    sh "make ensure-protoc-installed"
                    sh "make install-deps-if-needed"
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
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
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
                dir("$AISPHERE/${env.DOCKER_REPO_NAME}") {
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
