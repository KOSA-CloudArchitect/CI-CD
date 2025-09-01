pipeline {
    agent {
        kubernetes {
            label 'podman-node-agent'
            // [수정] YAML 정의 부분의 들여쓰기 및 구조를 올바르게 수정
            yaml """
apiVersion: v1
kind: Pod
spec:
  # Agent Pod가 jenkins 네임스페이스의 default 서비스 계정 권한을 사용하도록 지정
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
        ECR_REPOSITORY_URI = '833779331984.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
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

        stage('Build & Push Container Image') {
            steps {
                // [수정] script 블록과 불필요한 dir 단계를 제거하여 단순화
                container('aws-cli') {
                    script {
                        // ECR 비밀번호를 가져와 Jenkins 환경 변수에 저장
                        env.ECR_PASSWORD = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    }
                }
                
                dir('web-server-src/backend') {
                    container('podman') {
                        script {
                            def imageTag = "build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"
                            
                            // withCredentials를 사용하여 비밀번호를 안전하게 주입
                            withCredentials([string(credentialsId: 'ecr-login-password', variable: 'UNUSED')]) {
                                sh "echo '${env.ECR_PASSWORD}' | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                            }
                            
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
