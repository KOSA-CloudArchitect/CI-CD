// Jenkinsfile (CI-CD 레포지토리용 최종 버전)

pipeline {
    // 에이전트는 Pod Template에 정의된 'podman-agent'를 사용
    agent { label 'podman-agent' }

    environment {
        // GCP / Artifact Registry
        GCP_PROJECT_ID    = 'kwon-cicd'
        GCP_REGION        = 'asia-northeast3'
        GCR_REGISTRY_HOST = "${GCP_REGION}-docker.pkg.dev"
        GCR_REPO_PATH     = 'my-web-app-repo/web-server-backend'
        IMAGE_NAME        = "${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_PATH}"
        IMAGE_TAG         = "${env.BUILD_NUMBER}"

        // GitHub & Helm
        HELM_CHART_PATH   = 'helm-chart/my-web-app'
        GITHUB_ORG        = 'KOSA-CloudArchitect'
        GITHUB_REPO_WEB   = 'web-server'
        GITHUB_REPO_CICD  = 'CI-CD'
        GITHUB_USER       = 'kwon0905'
    }

    stages {
        stage('Checkout Web-Server Code') {
            steps {
                // 애플리케이션 소스 코드 클론
                withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                    sh "git clone https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_WEB}.git"
                }
            }
        }

        stage('Build and Push Application Image') {
            steps {
                // podman 명령어를 실행할 컨테이너를 명시
                container('podman-agent') {
                    dir("${GITHUB_REPO_WEB}/backend") {
                        script {
                            def fullImageName = "${IMAGE_NAME}:${IMAGE_TAG}"
                            echo "Building and pushing image: ${fullImageName}"
                            
                            // Workload Identity가 자동으로 인증하므로 별도 로그인 불필요
                            
                            // 1. Podman으로 이미지 빌드
                            sh "podman build -t ${fullImageName} ."

                            // 2. Artifact Registry로 이미지 푸시
                            sh "podman push ${fullImageName}"
                        }
                    }
                }
            }
        }

        stage('Update Helm Chart in Git') {
            steps {
                // git, sed 명령어 실행을 위해 podman-agent 컨테이너 사용
                container('podman-agent') {
                    withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                        sh """
                            set -e
                            
                            echo "Configuring Git user..."
                            git config user.email "jenkins-ci@example.com"
                            git config user.name  "Jenkins CI"

                            echo "Updating values.yaml with new image tag: ${IMAGE_TAG}"
                            sed -i 's|^    tag:.*|    tag: "${IMAGE_TAG}"|' "${HELM_CHART_PATH}/values.yaml"

                            echo "Committing and pushing changes to CI-CD repository..."
                            git add "${HELM_CHART_PATH}/values.yaml"
                            # 변경사항이 없으면 커밋하지 않도록 --allow-empty 옵션 제거
                            git commit -m "Update image tag to ${IMAGE_TAG} for build #${IMAGE_TAG}"
                            git push "https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_CICD}.git" HEAD:main
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            // 빌드 성공/실패와 관계없이 항상 워크스페이스 정리
            // Workspace Cleanup 플러그인이 설치되어 있어야 함
            cleanWs()
        }
        success {
            echo "CI Pipeline completed successfully! Image: ${IMAGE_NAME}:${IMAGE_TAG}"
            echo "Argo CD will now detect the changes and start deployment."
        }
        failure {
            echo "CI Pipeline failed."
        }
    }
}
