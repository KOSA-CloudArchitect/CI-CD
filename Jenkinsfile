pipeline {
    agent {
        kubernetes {
            label 'podman-node-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  # [추가] Jenkins Controller와 동일한 서비스 계정 사용을 명시
  # 이 서비스 계정은 EKS에 접근 권한이 있도록 aws-auth에 등록되어 있어야 함
  # 이전에 jenkins-rbac.yaml로 생성했음.
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

    // ... 나머지 stages는 이전과 동일 ...
    stages {
        // ...
        stage('Build & Push Container Image') {
            steps {
                script {
                    def ecrLoginPassword
                    container('aws-cli') {
                        ecrLoginPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    }
                    container('podman') {
                        dir('web-server-src/backend') {
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
        // ...
    }
}
