pipeline {
    agent {
        kubernetes {
            defaultContainer 'node' // 모든 sh 명령의 기본 실행 컨테이너를 'node'로 지정
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: default
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args: ["\$(JENKINS_SECRET)", "\$(JENKINS_NAME)"]
  - name: node
    image: node:18-slim
    command: ["sleep"], args: ["infinity"]
  - name: podman
    image: quay.io/podman/stable
    command: ["sleep"], args: ["infinity"]
    securityContext:
      privileged: true
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep"], args: ["infinity"]
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_BACKEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-backend'
        GITHUB_CREDENTIAL_ID = 'github-pat'
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                dir('web-server-src') {
                    git branch: 'main',
                        credentialsId: GITHUB_CREDENTIAL_ID,
                        url: 'https://github.com/KOSA-CloudArchitect/web-server.git'
                }
            }
        }

        // --- [수정] 프론트엔드 부분을 제거하고 백엔드 빌드/푸시만 남김 ---
        stage('Build & Push Backend') {
            steps {
                script {
                    def ecrLoginPassword
                    // 1. aws-cli 컨테이너에서 ECR 비밀번호 가져오기
                    container('aws-cli') {
                        ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    }

                    // 2. backend 폴더로 이동하여 빌드 및 푸시
                    dir('web-server-src/backend') {
                        // 2a. node 컨테이너에서 빌드
                        container('node') {
                            sh 'npm install'
                            sh 'npm run build'
                        }
                        // 2b. podman 컨테이너에서 이미지 생성 및 푸시
                        container('podman') {
                            sh "echo '${ecrLoginPassword}' | podman login --username AWS --password-stdin ${ECR_BACKEND_URI}"
                            
                            def imageTag = "backend-build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_BACKEND_URI}:${imageTag}"
                            
                            sh "podman build -t ${fullImageName} ."
                            sh "podman push ${fullImageName}"

                            env.BACKEND_IMAGE_TAG = imageTag
                        }
                    }
                }
            }
        }

        stage('Update Manifest') {
            steps {
                withCredentials([string(credentialsId: GITHUB_CREDENTIAL_ID, variable: 'GITHUB_TOKEN')]) {
                    sh """
                        git clone https://x-access-token:${GITHUB_TOKEN}@github.com/KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        # 백엔드 Helm Chart만 수정
                        sed -i "s/tag: .*/tag: \\"${env.BACKEND_IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_BACKEND_URI}|g" helm-chart/my-web-app/values.yaml

                        git add helm-chart/my-web-app/values.yaml
                        git commit -m "Deploy new backend image: ${env.BACKEND_IMAGE_TAG}"
                        git push
                    """
                }
            }
        }
    }
}
