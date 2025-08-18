// GitHub의 CI-CD 레포지토리에 저장될 Jenkinsfile (Scripted Pipeline 형식)

node('podman-agent') {
    
    try {
        stage('Checkout Web-Server Code') {
            withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
                sh "git clone https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
            }
        }

        stage('Build & Push Docker Image (Podman)') {
            dir("${env.GITHUB_REPO_WEB}/backend") {
                def fullImageName = "${env.GCR_REGISTRY_HOST}/${env.GCP_PROJECT_ID}/${env.GCR_REPO_NAME}:${env.BUILD_NUMBER}"
                echo "Building with Podman: ${fullImageName}"
                
                sh "podman build -t ${fullImageName} ."
                sh "podman push ${fullImageName}"
            }
        }

        stage('Update Helm Chart & Push to CI-CD Repo') {
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
    } catch (e) {
        // 빌드가 실패하면 에러를 출력하고 빌드를 실패 상태로 만듦
        echo "Pipeline failed: ${e.getMessage()}"
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        // 빌드의 성공/실패 여부와 관계없이 항상 실행
        stage('Cleanup') {
            echo "Cleaning up workspace..."
            cleanWs()
        }
    }
}
