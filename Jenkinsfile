// GitHub의 CI-CD 레포지토리에 저장될 Jenkinsfile의 최종 내용

// pipeline { ... } 블록이 없는 상태여야 합니다.
agent { label 'podman-agent' }

environment {
    // GCP 및 이미지 정보
    GCP_PROJECT_ID    = 'kwon-cicd'
    GCP_REGION        = 'asia-northeast3'
    GCR_REGISTRY_HOST = "asia-northeast3-docker.pkg.dev"
    GCR_REPO_NAME     = "my-web-app-repo/web-server-backend"
    IMAGE_NAME        = "${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_NAME}"
    IMAGE_TAG         = "${env.BUILD_NUMBER}"

    // Helm 차트 및 GitHub 정보
    HELM_CHART_PATH   = 'helm-chart/my-web-app'
    GITHUB_ORG        = 'KOSA-CloudArchitect'
    GITHUB_REPO_WEB   = 'web-server'
    GITHUB_REPO_CICD  = 'CI-CD'
    GITHUB_USER       = 'kwon0905'
}

stages {
    stage('Checkout Web-Server Code') {
        steps {
            // 시작 스크립트에서 사용한 것과 동일한 Credential ID 사용
            withCredentials([string(credentialsId: 'github-pat-token-scm', variable: 'PAT')]) {
                sh "git clone https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_WEB}.git"
            }
        }
    }

    stage('Build & Push Docker Image (Podman)') {
        steps {
            container('podman-agent') {
                dir("${GITHUB_REPO_WEB}/backend") {
                    sh "podman build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    sh "podman push ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
    }

    stage('Update Helm Chart & Push to CI-CD Repo') {
        steps {
            container('podman-agent') {
                dir('.') { // CI-CD 레포지토리의 루트에서 실행
                    sh "git config user.email 'jenkins@${GITHUB_ORG}.com'"
                    sh "git config user.name 'Jenkins CI Automation'"
                    sh "sed -i 's|^    tag:.*|    tag: \"${IMAGE_TAG}\"|' ${HELM_CHART_PATH}/values.yaml"
                    sh "git add ${HELM_CHART_PATH}/values.yaml"
                    sh "git commit -m 'Update image tag to ${IMAGE_TAG} by Jenkins build #${env.BUILD_NUMBER}'"
                    withCredentials([string(credentialsId: 'github-pat-token-scm', variable: 'PAT')]) {
                        sh "git push https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_CICD}.git HEAD:main"
                    }
                }
            }
        }
    }
}

post {
    always {
        cleanWs()
    }
}
