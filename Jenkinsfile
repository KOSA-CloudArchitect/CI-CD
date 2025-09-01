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
    - "\\\$\\{JENKINS_SECRET\\}"
    - "\\\$\\{JENKINS_NAME\\}"
  - name: node
    image: node:18-slim
    command: ["sleep"]
    args: ["99d"]
  - name: podman
    image: quay.io/podman/stable:latest
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
        GITOPS_CREDENTIAL_ID = 'gitops-repo-deploy-key'
    }

    stages {
        stage('Debug IAM Role') {
            steps {
                container('aws-cli') {
                    sh 'aws sts get-caller-identity'
                }
            }
        }

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

        stage('ECR Login') {
            steps {
                container('aws-cli') {
                    script {
                        // ECR 로그인 명령을 Podman 컨테이너에서 실행하도록 환경 변수로 전달
                        env.ECR_PASSWORD = sh(
                            script: "aws ecr get-login-password --region ${AWS_REGION}",
                            returnStdout: true
                        ).trim()
                    }
                }

                container('podman') {
                    sh "echo '${env.ECR_PASSWORD}' | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                }
            }
        }

        stage('Build & Push Container Image') {
            steps {
                dir('web-server-src/backend') {
                    container('podman') {
                        script {
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

        stage('Update Helm Manifest') {
            steps {
                sshagent(credentials: [GITOPS_CREDENTIAL_ID]) {
                    sh """
                        git clone git@github.com:KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        sed -i "s/tag: .*/tag: \\"${env.IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"
                        git add helm-chart/my-web-app/values.yaml
                        git commit -m "Deploy web-server new image: ${env.IMAGE_NAME}"
                        git push
                    """
                }
            }
        }
    }
}

