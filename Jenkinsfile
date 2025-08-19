// GitHub의 CI-CD 레포지토리에 저장될 Jenkinsfile

node('podman-agent') {
    try {
        stage('Checkout Web-Server Code') {
            withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                sh "git clone https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
            }
        }

        stage('Build & Push Docker Image') {
            container('podman-agent') {
                dir("${env.GITHUB_REPO_WEB}/backend") {
                    def fullImageName = "${env.GCR_REGISTRY_HOST}/${env.GCP_PROJECT_ID}/${env.GCR_REPO_NAME}:${env.BUILD_NUMBER}"
                    echo "Building with Podman: ${fullImageName}"

                    // ✨ GCP 서비스 계정 키 파일을 사용하여 Artifact Registry 인증
                    // 'gcp-sa-key'는 Jenkins Credentials에 등록된 Secret File의 ID여야 함.
                    // Podman Agent 설정의 Mount Path와 일치시켜야 함.
                    withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GCP_KEY_FILE')]) {
                        echo "Authenticating to GCP Artifact Registry..."
                        
                        // 1. gcloud 명령어로 서비스 계정 인증
                        sh "gcloud auth activate-service-account --key-file=${GCP_KEY_FILE}"
                        
                        // 2. gcloud에서 발급받은 액세스 토큰으로 Podman에 로그인
                        sh "gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin ${env.GCR_REGISTRY_HOST}"
                        
                        // ✨ Podman 빌드 및 푸시
                        sh "podman build -t ${fullImageName} ."
                        sh "podman push ${fullImageName}"
                    }
                }
            }
        }

        stage('Update Helm Chart & Push') {
            container('podman-agent') {
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
    } catch (e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        stage('Cleanup') {
            cleanWs()
        }
    }
}
