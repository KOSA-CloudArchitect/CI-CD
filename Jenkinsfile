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
        ECR_BACKEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-backend'
        ECR_FRONTEND_URI = '890571109462.dkr.ecr.ap-northeast-2.amazonaws.com/web-server-frontend'
        // [수정] Clone용과 Push용 Credential ID를 분리
        GIT_CLONE_CREDENTIAL_ID = 'github-pat'
        GIT_PUSH_CREDENTIAL_ID = 'github-pat-text' 
    }

    stages {
        // ... (Build & Push 단계는 동일) ...

        stage('Update Manifests') {
            steps {
                // Push는 Secret text 타입 사용
                withCredentials([string(credentialsId: GIT_PUSH_CREDENTIAL_ID, variable: 'GITHUB_TOKEN')]) {
                    sh """
                        # HTTPS와 토큰으로 인증하여 클론
                        git clone https://x-access-token:${GITHUB_TOKEN}@github.com/KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        # Backend Helm Chart 수정
                        sed -i "s/tag: .*/tag: \\"${env.BACKEND_IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_BACKEND_URI}|g" helm-chart/my-web-app/values.yaml

                        # Frontend Helm Chart 수정 (경로 예시)
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

        stage('Update Manifest') {
            steps {
                withCredentials([string(credentialsId: GITHUB_CREDENTIAL_ID, variable: 'GITHUB_TOKEN')]) {
                    sh """
                        git clone https://x-access-token:${GITHUB_TOKEN}@github.com/KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                        cd ci-cd-repo
                        git checkout aws-test

                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        # 백엔드 Helm Chart만 수정
                        sed -i "s/tag: .*/tag: \\"${env.BACKEND_IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_BACKEND_URI}|g" helm-chart/my-web-app/values.yaml

                        git add helm-chart/my-web-app/values.yaml
                        git commit -m "Deploy new backend image: ${env.BACKEND_IMAGE_TAG}"
                        git push
                    """
                }
            }
        }
    }
}
