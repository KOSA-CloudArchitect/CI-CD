pipeline {
    agent {
        kubernetes {
            label 'podman-node-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    args:
    - "\$(JENKINS_SECRET)"
    - "\$(JENKINS_NAME)"
    env:
    - name: JENKINS_URL
      value: "http://172.16.179.121:8080"
    - name: JENKINS_TUNNEL
      value: "172.16.179.121:50000"
  - name: node
    image: node:18-slim
    command:
    - sleep
    args:
    - 99d
  - name: podman
    image: quay.io/podman/stable
    command:
    - sleep
    args:
    - 99d
    securityContext:
      privileged: true
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPOSITORY_URI = '833779331984.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
        GITOPS_CREDENTIAL_ID = 'gitops-repo-deploy-key' 
    }

    stages {
        stage('Checkout Source & Config') {
            steps {
                // 1. CI-CD 리포지토리(Jenkinsfile, Dockerfile 등)는 기본으로 체크아웃됨
                checkout scm

                // 2. web-server의 소스 코드를 'web-server-src' 폴더에 체크아웃
                dir('web-server-src') {
                    git branch: 'main',
                        credentialsId: 'github-pat',
                        url: 'https://github.com/KOSA-CloudArchitect/web-server.git'
                }
            }
        }

        stage('Build Application') {
            steps {
                // web-server-src/backend 폴더로 이동하여 빌드
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
                // web-server-src/backend 폴더로 이동하여 이미지 빌드
                dir('web-server-src/backend') {
                    container('podman') {
                        script {
                            def imageTag = "build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"
                            // [수정] CI-CD 리포지토리에 있는 Dockerfile 경로를 -f 옵션으로 지정
                            def dockerfilePath = '../../dockerfiles/web-server/Dockerfile'

                            sh "aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                            sh "podman build -t ${fullImageName} -f ${dockerfilePath} ."
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
                // 이 단계는 CI-CD 리포지토리의 내용을 수정
                sshagent(credentials: [GITOPS_CREDENTIAL_ID]) {
                    sh """
                        sed -i "s/tag: .*/tag: \\"${env.IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"
                        git add helm-chart/my-web-app/values.yaml
                        git commit -m "Deploy web-server new image: ${env.IMAGE_NAME}"
                        git push origin HEAD:aws-test
                    """
                }
            }
        }
    }
}
