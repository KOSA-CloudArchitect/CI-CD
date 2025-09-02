pipeline {
    agent {
        kubernetes {
            label 'podman-node-agent'
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
    command: ["sleep"], args: ["99d"]
  - name: podman
    image: quay.io/podman/stable
    command: ["sleep"], args: ["99d"]
    securityContext:
      privileged: true
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep"], args: ["99d"]
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        // [수정] Backend와 Frontend ECR 주소를 각각 정확히 지정
        ECR_BACKEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-backend'
        ECR_FRONTEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-frontend'
        // CI-CD 리포지토리에 Push할 때 사용할 Credential ID
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

        stage('Build & Push All Services') {
            // Backend와 Frontend 빌드를 병렬로 동시 실행
            parallel {
                stage('Build & Push Backend') {
                    steps {
                        script {
                            def ecrLoginPassword
                            container('aws-cli') {
                                ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                            }
                            dir('web-server-src/backend') {
                                container('node') {
                                    sh 'npm install'
                                    sh 'npm run build'
                                }
                                container('podman') {
                                    sh "echo '${ecrLoginPassword}' | podman login --username AWS --password-stdin ${ECR_BACKEND_URI}"
                                    def imageTag = "backend-build-${BUILD_NUMBER}"
                                    def fullImageName = "${ECR_BACKEND_URI}:${imageTag}"
                                    sh "podman build -t ${fullImageName} ."
                                    sh "podman push ${fullImageName}"
                                    // 다음 스테이지에서 사용할 수 있도록 변수 저장
                                    env.BACKEND_IMAGE_NAME = fullImageName
                                    env.BACKEND_IMAGE_TAG = imageTag
                                }
                            }
                        }
                    }
                }

                stage('Build & Push Frontend') {
                    steps {
                        script {
                            def ecrLoginPassword
                            container('aws-cli') {
                                ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                            }
                            // web-server 리포지토리의 frontend 폴더 경로를 확인하고 맞춰야 합니다.
                            dir('web-server-src/frontend') { 
                                container('node') {
                                    sh 'npm install'
                                    sh 'npm run build'
                                }
                                container('podman') {
                                    sh "echo '${ecrLoginPassword}' | podman login --username AWS --password-stdin ${ECR_FRONTEND_URI}"
                                    def imageTag = "frontend-build-${BUILD_NUMBER}"
                                    def fullImageName = "${ECR_FRONTEND_URI}:${imageTag}"
                                    sh "podman build -t ${fullImageName} ."
                                    sh "podman push ${fullImageName}"
                                    env.FRONTEND_IMAGE_NAME = fullImageName
                                    env.FRONTEND_IMAGE_TAG = imageTag
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Update Manifests') {
            steps {
                // withCredentials를 사용하여 CI-CD 리포지토리에 Push
                withCredentials([string(credentialsId: GITHUB_CREDENTIAL_ID, variable: 'GITHUB_TOKEN')]) {
                    sh """
                        # HTTPS와 토큰으로 인증하여 클론
                        git clone https://x-access-token:${GITHUB_TOKEN}@github.com/KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        # Git 사용자 설정
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        # Backend Helm Chart 수정
                        sed -i "s/tag: .*/tag: \\"${env.BACKEND_IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_BACKEND_URI}|g" helm-chart/my-web-app/values.yaml

                        # Frontend Helm Chart 수정 (경로 예시)
                        sed -i "s/tag: .*/tag: \\"${env.FRONTEND_IMAGE_TAG}\\"/g" helm-chart/my-frontend-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_FRONTEND_URI}|g" helm-chart/my-frontend-app/values.yaml

                        # 변경사항 커밋 및 푸시
                        git add .
                        git commit -m "Deploy new images: backend ${env.BACKEND_IMAGE_TAG}, frontend ${env.FRONTEND_IMAGE_TAG}"
                        git push
                    """
                }
            }
        }
    }
}
