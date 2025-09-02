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
    args:
    - "\$(JENKINS_SECRET)"
    - "\$(JENKINS_NAME)"
  - name: node
    image: node:18-slim
    command: ["sleep"]
    args: ["99d"]
  - name: podman
    image: quay.io/podman/stable
    command: ["sleep"]
    args: ["99d"]
    securityContext:
      privileged: true
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["sleep"]
    args: ["99d"]
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPOSITORY_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
        GITOPS_CREDENTIAL_ID = 'gitops-repo-pat'
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                dir('web-server-src') {
                    git branch: 'main',
                        credentialsId: 'github-pat',
                        url: 'https://github.com/KOSA-CloudArchitect/web-server.git'
                }
            }
        }

        stage('Build Application') {
            steps {
                dir('web-server-src/backend') {
                    container('node') {
                        sh 'npm install'
                        sh 'npm run build'
                    }
                }
            }
        }

        stage('Build & Push Container Image') {
            steps {
                script {
                    def ecrLoginPassword
                    container('aws-cli') {
                        ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    }

                    dir('web-server-src/backend') {
                        container('podman') {
                            sh "echo '${ecrLoginPassword}' | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"

                            def imageTag = "build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"

                            sh "podman build -t ${fullImageName} ."
                            sh "podman push ${fullImageName}"

                            env.IMAGE_NAME = fullImageName
                            env.IMAGE_TAG = imageTag
                        }
                    }
                }
            }
        }


        stage('Update Manifest') {
            steps {
                // withCredentials 블록으로 git clone과 git push 모두를 감싸서 인증
                withCredentials([
                    // GitOps 리포지토리(CI-CD)에 Push할 때 사용할 PAT
                    string(credentialsId: 'gitops-repo-pat', variable: 'GITOPS_PAT'),
                    // web-server 리포지토리를 clone할 때 사용할 PAT
                    string(credentialsId: 'github-pat', variable: 'GITHUB_PAT')
                ]) {
                    sh """
                        # CI-CD 리포지토리를 PAT로 인증하여 클론
                        git clone https://x-access-token:${GITOPS_PAT}@github.com/KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        # Git 사용자 설정
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        # Helm Chart의 values.yaml 수정
                        sed -i "s/tag: .*/tag: \\"${env.IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                        # 변경사항 커밋 및 푸시
                        git add helm-chart/my-web-app/values.yaml
                        git commit -m "Deploy web-server new image: ${env.IMAGE_NAME}"
                        git push https://x-access-token:${GITOPS_PAT}@github.com/KOSA-CloudArchitect/CI-CD.git
                    """
                }
            }
        }
    }
}
