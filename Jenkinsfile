// 최종 수정된 선언형 파이프라인 (Declarative Pipeline)
pipeline {
    // 1. 에이전트 선언: 쿠버네티스 플러그인을 통해 podman-agent 파드를 사용합니다.
    agent {
        kubernetes {
            label 'podman-agent'
            defaultContainer 'podman-agent' // 모든 sh 명령어가 이 컨테이너에서 실행되도록 지정
        }
    }

    // 2. 환경 변수 정의: 파이프라인 전체에서 사용할 변수들을 이곳에 정의합니다.
    // 이전 'null/null.git' 오류의 원인이었던 부분입니다.
    environment {
        GCP_PROJECT_ID    = 'kwon-cicd'
        GCP_REGION        = 'asia-northeast3'
        GCR_REGISTRY_HOST = "asia-northeast3-docker.pkg.dev"
        GCR_REPO_NAME     = "my-web-app-repo/web-server-backend"
        HELM_CHART_PATH   = 'helm-chart/my-web-app'
        GITHUB_ORG        = 'KOSA-CloudArchitect'
        GITHUB_REPO_WEB   = 'web-server'
        GITHUB_REPO_CICD  = 'CI-CD'
        GITHUB_USER       = 'kwon0905'
    }

    // 3. 파이프라인의 각 단계(Stage) 정의
    stages {
        // ✨ 1단계: 애플리케이션 소스 코드 체크아웃
        stage('Checkout Web-Server Code') {
            steps {
                // web-server 디렉터리를 만들고 해당 레포지토리를 체크아웃합니다.
                dir('web-server') {
                    git branch: 'main', credentialsId: 'github-pat-token', url: "https://github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_WEB}.git"
                }
            }
        }

        // ✨ 2단계: Podman으로 컨테이너 이미지 빌드 및 푸시
        stage('Build & Push Docker Image') {
            steps {
                // web-server/backend 디렉터리로 이동하여 빌드 및 푸시를 수행합니다.
                dir("web-server/backend") {
                    script {
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
        }

        // ✨ 3단계: Helm Chart 업데이트 및 Git 푸시
        stage('Update Helm Chart & Push') {
            steps {
                script {
                    def imageTag = env.BUILD_NUMBER
                    echo "Updating Helm chart with image tag: ${imageTag}"

                    sh "git config user.email 'jenkins@example.com'"
                    sh "git config user.name 'Jenkins CI'"
                    sh "sed -i 's|^    tag:.*|    tag: \"${imageTag}\"|' ${env.HELM_CHART_PATH}/values.yaml"
                    sh "git add ${env.HELM_CHART_PATH}/values.yaml"
                    sh "git commit -m 'Update image tag to ${imageTag} by Jenkins build #${imageTag}'"

                    // GitHub PAT를 사용하여 원격 저장소에 푸시합니다.
                    withCredentials([string(credentialsId: 'github-pat-token-push', variable: 'PAT')]) {
                        sh "git push https://${env.GITHUB_USER}:${PAT}@github.com/${env.GITHUB_ORG}/${env.GITHUB_REPO_CICD}.git HEAD:main"
                    }
                }
            }
        }
    }

    // 4. 빌드 후 조치: 빌드의 성공/실패 여부와 관계없이 항상 실행됩니다.
    post {
        always {
            echo 'Pipeline finished. Cleaning up workspace...'
            cleanWs()
        }
    }
}
