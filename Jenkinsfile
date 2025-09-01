pipeline {
    agent {
        kubernetes {
            label 'podman-node-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  # [추가] Jenkins가 EKS API 접근 시 사용했던 서비스 계정을 Agent Pod에도 지정
  serviceAccountName: jenkins
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
  - name: aws-cli
    image: amazon/aws-cli:latest
    command:
    - sleep
    args:
    - 99d
"""
        }
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPOSITORY_URI = '833779331984.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
        GITOPS_CREDENTIAL_ID = 'gitops-repo-deploy-key'
    }

    stages {
        // ... 이전 stage들은 동일 ...

        stage('Build & Push Container Image') {
            steps {
                script {
                    // 이제 모든 컨테이너가 IAM Role 권한을 상속받으므로,
                    // podman 컨테이너 안에서 aws cli를 직접 호출할 수 있음.
                    // 단, podman 컨테이너에도 aws-cli가 설치되어 있어야 함.
                    // 가장 간단한 방법은 aws-cli 컨테이너에서 모든 것을 처리하는 것임.
                    container('aws-cli') {
                        // web-server-src/backend 폴더로 이동하여 이미지 관련 작업 수행
                        dir('web-server-src/backend') {
                            def imageTag = "build-${BUILD_NUMBER}"
                            def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"

                            // aws-cli 컨테이너에는 podman이 없으므로, 이 방법은 실패함.
                            // Pod Template의 컨테이너를 하나로 합치는 것이 가장 좋음.
                            // 임시 해결책으로, 각 컨테이너가 역할을 분담하도록 다시 수정.
                            def ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                            
                            // podman 컨테이너로 전환하여 로그인 및 빌드/푸시
                            container('podman') {
                                sh "echo '${ecrLoginPassword}' | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                                sh "podman build -t ${fullImageName} ."
                                sh "podman push ${fullImageName}"

                                env.IMAGE_NAME = fullImageName
                                env.IMAGE_TAG = imageTag
                            }
                        }
                    }
                }
            }
        }
        
        // ... 이후 stage는 동일 ...
    }
}
