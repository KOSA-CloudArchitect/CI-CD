// Jenkinsfile
// 이 파일은 CI-CD 레포지토리에 위치합니다.

pipeline {
    agent { label 'podman-agent' }

    environment {
        GCP_PROJECT_ID    = 'kwon-cicd'
        GCP_REGION        = 'asia-northeast3'
        GCR_REGISTRY_HOST = "${GCP_REGION}-docker.pkg.dev"
        GCR_REPO_NAME     = "my-web-app-repo/web-server-backend"
        IMAGE_TAG         = "${env.BUILD_NUMBER}"
        HELM_CHART_PATH   = 'helm-chart/my-web-app'
        GITHUB_ORG        = 'KOSA-CloudArchitect'
        GITHUB_REPO_WEB   = 'web-server'
        GITHUB_REPO_CICD  = 'CI-CD'
        GITHUB_USER       = 'kwon0905'
    }

    stages {
        stage('Checkout Web-Server Code') {
            steps {
                // 팀원의 web-server 레포지토리를 체크아웃합니다.
                // withCredentials 블록을 사용하여 PAT를 안전하게 전달합니다.
                withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                    sh "git clone https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_WEB}.git"
                }
            }
        }

        stage('Build & Push Docker Image (Podman)') {
            steps {
                script {
                    echo "Building with Podman: ${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_NAME}:${IMAGE_TAG}"
                    dir("web-server") {
                        dir("backend") {
                            sh "podman build -t ${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_NAME}:${IMAGE_TAG} ."
                            sh "podman push ${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_NAME}:${IMAGE_TAG}"
                        }
                    }
                }
            }
        }
        
        stage('Update Helm Chart & Push to CI/CD Repo') {
            steps {
                script {
                    // Jenkinsfile을 포함한 현재 CI/CD 레포지토리를 체크아웃합니다.
                    sh "git config user.email 'jenkins@${GITHUB_ORG}.com'"
                    sh "git config user.name 'Jenkins CI Automation'"
                    sh "sed -i 's|repository: .*|repository: ${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_NAME}|' ${HELM_CHART_PATH}/values.yaml"
                    sh "sed -i 's|tag: \".*\"|tag: \"${IMAGE_TAG}\"|' ${HELM_CHART_PATH}/values.yaml"
                    sh "git add ${HELM_CHART_PATH}/values.yaml"
                    sh "git commit -m 'Update image tag to ${IMAGE_TAG} by Jenkins build #${env.BUILD_NUMBER}'"

                    withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                        sh "git push https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_CICD}.git HEAD:main"
                    }
                }
            }
        }
    }

    post {
        always { cleanWs() }
        failure { echo 'CI/CD Pipeline failed!' }
        success { echo 'CI/CD Pipeline completed successfully! Argo CD should now deploy.' }
    }
}
