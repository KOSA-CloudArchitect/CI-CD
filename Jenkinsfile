// GitHub의 CI-CD 레포지토리에 저장될 Jenkinsfile (Scripted Pipeline 형식)

// 에이전트 Pod를 할당받고, 그 안에서 모든 작업을 실행
node('podman-agent') {
    
    // ----------------- STAGES START -----------------
    stage('Checkout Web-Server Code') {
        // 'env' 객체를 통해 환경 변수를 직접 사용
        withCredentials([string(credentialsId: 'github-pat-token-scm', variable: 'PAT')]) {
            sh "git clone https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
        }
    }

    stage('Build & Push Docker Image (Podman)') {
        container('podman-agent') {
            dir("${env.GITHUB_REPO_WEB}/backend") {
                script {
                    // 이미지 전체 이름을 직접 조합
                    def fullImageName = "${env.GCR_REGISTRY_HOST}/${env.GCP_PROJECT_ID}/${env.GCR_REPO_NAME}:${env.BUILD_NUMBER}"
                    echo "Building with Podman: ${fullImageName}"
                    
                    sh "podman build -t ${fullImageName} ."
                    sh "podman push ${fullImageName}"
                }
            }
        }
    }

    stage('Update Helm Chart & Push to CI/CD Repo') {
        container('podman-agent') {
            script {
                def imageTag = env.BUILD_NUMBER
                
                sh "git config user.email 'jenkins@${env.GITHUB_ORG}.com'"
                sh "git config user.name 'Jenkins CI Automation'"
                sh "sed -i 's|^    tag:.*|    tag: \"${imageTag}\"|' ${env.HELM_CHART_PATH}/values.yaml"
                sh "git add ${env.HELM_CHART_PATH}/values.yaml"
                sh "git commit -m 'Update image tag to ${imageTag} by Jenkins build #${imageTag}'"
                withCredentials([string(credentialsId: 'github-pat-token-scm', variable: 'PAT')]) {
                    sh "git push https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git HEAD:main"
                }
            }
        }
    }
    // ----------------- STAGES END -----------------

    // 'post' 블록 대신, 마지막에 항상 실행되는 코드를 추가
    stage('Cleanup') {
        cleanWs()
    }
}
