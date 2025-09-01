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
  # --- [추가] AWS CLI 명령어를 실행할 전용 컨테이너 ---
  - name: aws-cli
    image: amazon/aws-cli:latest
    command:
    - sleep
    args:
    - 99d
  # -----------------------------------------------
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPOSITORY_URI = '833779331984.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
        GITOPS_CREDENTIAL_ID = 'gitops-repo-deploy-key' 
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
                // [수정] ECR 로그인과 이미지 빌드/푸시를 분리
                script {
                    def ecrLoginPassword
                    // 1. 'aws-cli' 컨테이너에서 ECR 비밀번호를 가져와 변수에 저장
                    container('aws-cli') {
                        ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    }

                    // 2. web-server-src/backend 폴더로 이동하여 이미지 관련 작업 수행
                    dir('web-server-src/backend') {
                        // 3. 'podman' 컨테이너에서 위에서 얻은 비밀번호로 로그인, 빌드, 푸시 실행
                        container('podman') {
                            // Jenkins 스크립트 보안 때문에 비밀번호를 직접 사용
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
