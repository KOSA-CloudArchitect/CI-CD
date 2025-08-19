// GitHub의 CI-CD 레포지토리에 저장될 Jenkinsfile

// 젠킨스 에이전트 내에서 모든 작업이 이루어지므로, node 블록은 제거됩니다.
try {
    // ✨ 새로 추가된 CI-CD 저장소 체크아웃 단계
    stage('Checkout CI-CD Repo') {
        withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
            sh "git clone https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git ."
        }
    }

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

                withCredentials([file(credentialsId: 'gcp-sa-key', variable: 'GCP_KEY_FILE')]) {
                    echo "Authenticating to GCP Artifact Registry..."
                    sh "gcloud auth activate-service-account --key-file=${GCP_KEY_FILE}"
                    sh "gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin ${env.GCR_REGISTRY_HOST}"

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
