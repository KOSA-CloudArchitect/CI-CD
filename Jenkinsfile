pipeline {
    agent {
        kubernetes {
            // 1. Pod 템플릿의 핵심은 유지하되, 모든 작업이 실행될 기본 컨테이너를 지정합니다.
            defaultContainer 'node'
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
    command: ["sleep"]
    args: ["infinity"]
  - name: podman
    image: quay.io/podman/stable
    command: ["sleep"]
    args: ["infinity"]
    securityContext:
      privileged: true
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep"]
    args: ["infinity"]
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_BACKEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-backend'
        ECR_FRONTEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-frontend'
        GITHUB_CREDENTIAL_ID = 'github-pat'
    }

    stages {
        stage('Checkout & Build & Push') {
            // 2. 모든 작업을 하나의 스테이지에서 순차적으로 실행하여 충돌 방지
            steps {
                script {
                    // --- 체크아웃 ---
                    dir('web-server-src') {
                        git branch: 'main',
                            credentialsId: GITHUB_CREDENTIAL_ID,
                            url: 'https://github.com/KOSA-CloudArchitect/web-server.git'
                    }

                    // --- 백엔드 빌드 & 푸시 ---
                    echo "--- Building & Pushing Backend ---"
                    dir('web-server-src/backend') {
                        container('node') {
                            sh 'npm install'
                            sh 'npm run build'
                        }
                        container('podman') {
                            def imageTag = "backend-build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_BACKEND_URI}:${imageTag}"
                            sh "podman build -t ${fullImageName} ."
                            container('aws-cli') {
                                sh "aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_BACKEND_URI}"
                            }
                            sh "podman push ${fullImageName}"
                            env.BACKEND_IMAGE_TAG = imageTag
                        }
                    }

                    // --- 프론트엔드 빌드 & 푸시 ---
                    echo "--- Building & Pushing Frontend ---"
                    dir('web-server-src/frontend') {
                        container('node') {
                            sh 'npm install'
                            sh 'npm run build'
                        }
                        container('podman') {
                            def imageTag = "frontend-build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_FRONTEND_URI}:${imageTag}"
                            sh "podman build -t ${fullImageName} ."
                            container('aws-cli') {
                                sh "aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_FRONTEND_URI}"
                            }
                            sh "podman push ${fullImageName}"
                            env.FRONTEND_IMAGE_TAG = imageTag
                        }
                    }
                }
            }
        }

        stage('Update Manifests') {
            steps {
                withCredentials([string(credentialsId: GITHUB_CREDENTIAL_ID, variable: 'GITHUB_TOKEN')]) {
                    sh """
                        git clone https://x-access-token:${GITHUB_TOKEN}@github.com/KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        sed -i "s/tag: .*/tag: \\"${env.BACKEND_IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_BACKEND_URI}|g" helm-chart/my-web-app/values.yaml

                        sed -i "s/tag: .*/tag: \\"${env.FRONTEND_IMAGE_TAG}\\"/g" helm-chart/my-frontend-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_FRONTEND_URI}|g" helm-chart/my-frontend-app/values.yaml

                        git add .
                        git commit -m "Deploy new images: backend ${env.BACKEND_IMAGE_TAG}, frontend ${env.FRONTEND_IMAGE_TAG}"
                        git push
                    """
                }
            }
        }
    }
}
