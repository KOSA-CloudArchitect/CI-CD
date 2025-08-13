// Jenkinsfile
// 이 파일은 CI-CD 레포지토리에 위치합니다.

pipeline {
    // 에이전트는 podman 명령어를 실행할 수 있는 Pod 템플릿을 사용합니다.
    agent { label 'podman-agent' }

    environment {
        // GCP 및 이미지 정보
        GCP_PROJECT_ID    = 'kwon-cicd'
        GCP_REGION        = 'asia-northeast3'
        GCR_REGISTRY_HOST = "${GCP_REGION}-docker.pkg.dev"
        GCR_REPO_NAME     = "my-web-app-repo/web-server-backend"
        
        // 최종 이미지 이름을 환경 변수로 통합하여 관리합니다.
        IMAGE_NAME        = "${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_NAME}"
        
        // 빌드 번호를 이미지 태그로 사용합니다.
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
                // 애플리케이션 소스 코드가 있는 web-server 레포지토리를 클론합니다.
                withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                    sh "git clone https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_WEB}.git"
                }
            }
        }

        stage('Build & Push Docker Image (Podman)') {
            steps {
                //  podman 명령어를 실행하기 위해 'podman-agent' 컨테이너를 명시적으로 지정합니다.
                container('podman-agent') {
                    script {
                        echo "Building with Podman: ${IMAGE_NAME}:${IMAGE_TAG}"
                        
                        // 작업 디렉터리를 애플리케이션의 backend 폴더로 변경합니다.
                        dir("${GITHUB_REPO_WEB}/backend") {
                            // 1. GCP Artifact Registry에 인증합니다. (Pod의 서비스 계정 권한 사용)
                            sh "gcloud auth configure-docker ${GCR_REGISTRY_HOST}"
                            
                            // 2. Podman으로 이미지를 빌드합니다.
                            sh "podman build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                            
                            // 3. 빌드된 이미지를 Artifact Registry로 푸시합니다.
                            sh "podman push ${IMAGE_NAME}:${IMAGE_TAG}"
                        }
                    }
                }
            }
        }

        stage('Update Helm Chart & Push to CI/CD Repo') {
            steps {
                // ❗ git, sed 명령어의 일관된 실행 환경을 위해 'podman-agent' 컨테이너를 사용합니다.
                container('podman-agent') {
                    script {
                        // Git 커밋을 위한 사용자 정보를 설정합니다.
                        sh "git config user.email 'jenkins@${GITHUB_ORG}.com'"
                        sh "git config user.name 'Jenkins CI Automation'"

                        // Helm 차트의 values.yaml 파일에서 이미지 태그를 현재 빌드 번호로 변경합니다.
                        sh "sed -i 's|^    tag:.*|    tag: \"${IMAGE_TAG}\"|' ${HELM_CHART_PATH}/values.yaml"
                        
                        // 변경된 values.yaml 파일을 git에 추가하고 커밋합니다.
                        sh "git add ${HELM_CHART_PATH}/values.yaml"
                        sh "git commit -m 'Update image tag to ${IMAGE_TAG} by Jenkins build #${env.BUILD_NUMBER}'"

                        // PAT를 사용하여 CI-CD 레포지토리에 변경 사항을 푸시합니다.
                        withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                            sh "git push https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_CICD}.git HEAD:main"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            // 빌드 성공/실패와 관계없이 항상 워크스페이스를 정리합니다.
            cleanWs()
        }
        failure {
            echo 'CI/CD Pipeline failed!'
        }
        success {
            echo 'CI/CD Pipeline completed successfully! Argo CD should now deploy.'
        }
    }
}
