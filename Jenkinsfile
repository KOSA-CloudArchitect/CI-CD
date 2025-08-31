pipeline {
    // agent를 YAML로 직접 정의
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
    args: \$(JENKINS_SECRET) \$(JENKINS_NAME)
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
        stage('Checkout Application Code') {
            steps {
                // web-server의 소스 코드를 'web-server-src'라는 폴더에 체크아웃
                git branch: 'aws-test',
                    credentialsId: 'github-pat',
                    url: 'https://github.com/KOSA-CloudArchitect/web-server.git',
                    dir: 'web-server-src'
            }
        }

        stage('Build Application') {
            steps {
                dir('web-server-src') {
                    // 'node' 컨테이너 안에서 Node.js 빌드 명령어 실행
                    container('node') {
                        sh 'npm install'
                    }
                }
            }
        }

        stage('Build & Push Container Image') {
            steps {
                dir('web-server-src') {
                    // 'podman' 컨테이너 안에서 이미지 빌드 및 푸시 실행
                    container('podman') {
                        script {
                            def imageTag = "build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"

                            sh "aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
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
                        # CI-CD 리포지토리를 별도의 폴더에 클론
                        git clone git@github.com:KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        # Helm Chart의 values.yaml 수정
                        sed -i "s/tag: .*/tag: \\"${env.IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                        # Git 설정 및 Push
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
