// GitHub의 CI-CD 레포지토리에 저장될 Jenkinsfile

node('podman-agent') {
    
    try {
        stage('Checkout Web-Server Code') {
            withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                sh "git clone https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
            }
        }

        // ❗ podman 명령어를 사용하므로 container 블록 추가
        stage('Build & Push Docker Image (Podman)') {
            container('podman-agent') {
                dir("${env.GITHUB_REPO_WEB}/backend") {
                    def fullImageName = "${env.GCR_REGISTRY_HOST}/${env.GCP_PROJECT_ID}/${env.GCR_REPO_NAME}:${env.BUILD_NUMBER}"
                    echo "Building with Podman: ${fullImageName}"
                    
                    sh "podman build -t ${fullImageName} ."
                    sh "podman push ${fullImageName}"
                }
            }
        }

        // ❗ git, sed 명령어는 podman-agent 컨테이너에 있으므로 container 블록 추가
        stage('Update Helm Chart & Push to CI-CD Repo') {
            container('podman-agent') {
                def imageTag = env.BUILD_NUMBER
                
                sh "git config user.email 'jenkins@${env.GITHUB_ORG}.com'"
                sh "git config user.name 'Jenkins CI Automation'"
                sh "sed -i 's|^    tag:.*|    tag: \"${imageTag}\"|' ${env.HELM_CHART_PATH}/values.yaml"
                sh "git add ${env.HELM_CHART_PATH}/values.yaml"
                sh "git commit -m 'Update image tag to ${imageTag} by Jenkins build #${imageTag}'"
                
                withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                    sh "git push https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git HEAD:main"
                }
            }
        }
    } catch (e) {
        echo "Pipeline failed: ${e.getMessage()}"
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        stage('Cleanup') {
            echo "Cleaning up workspace..."
            cleanWs()
        }
    }
}
