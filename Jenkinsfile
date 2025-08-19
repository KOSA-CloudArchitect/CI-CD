// 최종 완성된 선언형 파이프라인 (Declarative Pipeline)
pipeline {
    agent {
        kubernetes {
            label 'podman-agent'
            defaultContainer 'podman-agent'
        }
    }

    options {
        skipDefaultCheckout true
    }

    environment {
        GCP_PROJECT_ID    = 'kwon-cicd'
        GCP_REGION        = 'asia-northeast3'
        GCR_REGISTRY_HOST = "asia-northeast3-docker.pkg.dev"
        GCR_REPO_NAME     = "my-web-app-repo/web-server-backend"
        HELM_CHART_PATH   = 'helm-chart/my-web-app'
        GITHUB_ORG        = 'KOSA-CloudArchitect'
        GITHUB_REPO_WEB   = 'web-server'
        GITHUB_REPO_CICD  = 'CI-CD'
        GITHUB_USER       = 'kwon0905'
    }

    stages {
        // 1단계: CI-CD 레포지토리 직접 체크아웃
        stage('Checkout CI-CD Repo') {
            steps {
                git branch: 'main', credentialsId: 'github-pat-token', url: "https://github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git"
            }
        }

        // 2단계: 애플리케이션 소스 코드 체크아웃
        stage('Checkout Web-Server Code') {
            steps {
                dir('web-server') {
                    git branch: 'main', credentialsId: 'github-pat-token', url: "https://github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
                }
            }
        }

        // 3단계: Podman으로 컨테이너 이미지 빌드 및 푸시
        stage('Build & Push Docker Image') {
            steps {
                dir("web-server/backend") {
                    script {
                        def fullImageName = "${env.GCR_REGISTRY_HOST}/${env.GCP_PROJECT_ID}/${env.GCR_REPO_NAME}:${env.BUILD_NUMBER}"
                        echo "Building with Podman: ${fullImageName}"
                        withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GCP_KEY_FILE')]) {
                            sh "gcloud auth activate-service-account --key-file=${GCP_KEY_FILE}"
                            sh "gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin ${env.GCR_REGISTRY_HOST}"
                            sh "podman build -t ${fullImageName} ."
                            sh "podman push ${fullImageName}"
                        }
                    }
                }
            }
        }

        // 4단계: Helm Chart 업데이트 및 Git 푸시
        stage('Update Helm Chart & Push') {
            steps {
                dir(env.WORKSPACE) {
                    script {
                        // ---▼▼▼  'dubious ownership' 문제 해결을 위한 코드  ▼▼▼---
                        sh "git config --global --add safe.directory ${env.WORKSPACE}"
                        // ---▲▲▲ 여기까지가 핵심 해결 코드입니다 ▲▲▲---

                        def imageTag = env.BUILD_NUMBER
                        sh "git config user.email 'jenkins@example.com'"
                        sh "git config user.name 'Jenkins CI'"
                        sh "sed -i 's|^    tag:.*|    tag: \"${imageTag}\"|' ${env.HELM_CHART_PATH}/values.yaml"
                        sh "git add ${env.HELM_CHART_PATH}/values.yaml"
                        sh "git commit -m 'Update image tag to ${imageTag} by Jenkins build #${imageTag}'"
                        withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                            sh "git push https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git HEAD:main"
                        }
                    }
                }
            }
        }
    }

    // 빌드 후 항상 작업 공간을 정리합니다.
    post {
        always {
            cleanWs()
        }
    }
}
