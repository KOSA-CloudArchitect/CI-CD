// Jenkinsfile (수정된 최종 버전)
// SCM으로부터 직접 실행되도록 구성

// podman-agent 파드를 에이전트로 지정
node('podman-agent') {
    try {
        // podman-agent 컨테이너 내부에서 모든 작업을 수행
        container('podman-agent') {

            // ✨ 1. 애플리케이션 소스 코드 체크아웃
            stage('Checkout Web-Server Code') {
                // web-server 디렉터리를 만들어 해당 레포지토리를 체크아웃
                dir('web-server') {
                    git branch: 'main', credentialsId: 'github-pat-token', url: "https://github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
                }
            }

            // ✨ 2. Podman을 사용해 컨테이너 이미지 빌드 및 푸시
            stage('Build & Push Docker Image') {
                // web-server/backend 디렉터리로 이동하여 빌드 수행
                dir("web-server/backend") {
                    def fullImageName = "${env.GCR_REGISTRY_HOST}/${env.GCP_PROJECT_ID}/${env.GCR_REPO_NAME}:${env.BUILD_NUMBER}"
                    echo "Building with Podman: ${fullImageName}"

                    // GCP 서비스 계정 키 파일을 사용하여 인증
                    withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GCP_KEY_FILE')]) {
                        echo "Authenticating to GCP Artifact Registry..."
                        sh "gcloud auth activate-service-account --key-file=${GCP_KEY_FILE}"
                        sh "gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin ${env.GCR_REGISTRY_HOST}"

                        // Podman으로 이미지 빌드 및 Artifact Registry로 푸시
                        sh "podman build -t ${fullImageName} ."
                        sh "podman push ${fullImageName}"
                    }
                }
            }

            // ✨ 3. Helm Chart의 이미지 태그 업데이트 및 Git 푸시
            stage('Update Helm Chart & Push') {
                // 이 스테이지는 이미 CI-CD 레포지토리 루트에서 실행되므로 dir() 블록이 필요 없음
                def imageTag = env.BUILD_NUMBER

                // Git 사용자 정보 설정
                sh "git config user.email 'jenkins@example.com'"
                sh "git config user.name 'Jenkins CI'"

                // values.yaml 파일의 이미지 태그를 현재 빌드 번호로 변경
                sh "sed -i 's|^    tag:.*|    tag: \"${imageTag}\"|' ${env.HELM_CHART_PATH}/values.yaml"

                // 변경된 파일 add 및 commit
                sh "git add ${env.HELM_CHART_PATH}/values.yaml"
                sh "git commit -m 'Update image tag to ${imageTag} by Jenkins build #${imageTag}'"

                // GitHub PAT 토큰을 사용하여 원격 레포지토리에 푸시
                withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                    sh "git push https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git HEAD:main"
                }
            }
        } // container('podman-agent') 블록의 끝
    } catch (e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        // 빌드 후 작업 공간 정리
        stage('Cleanup') {
            cleanWs()
        }
    }
}
