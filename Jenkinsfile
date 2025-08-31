pipeline {
    // 1. EKS 위에 생성할 Pod 템플릿의 Label을 에이전트로 지정
    agent {
        label 'podman-node-agent'
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPOSITORY_URI = '833779331984.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
        // Jenkins Credential에 등록된 SSH 배포 키 ID
        GITOPS_CREDENTIAL_ID = 'gitops-repo-deploy-key' 
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                // 'web-server'의 소스 코드를 'web-server-src'라는 폴더에 체크아웃
                git branch: 'aws-test',
                    credentialsId: 'github-pat',
                    url: 'https://github.com/KOSA-CloudArchitect/web-server.git',
                    dir: 'web-server-src'
            }
        }

        stage('Build Application') {
            steps {
                // web-server-src 폴더로 이동하여 작업 수행
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
                // web-server-src 폴더로 이동하여 작업 수행
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
                // 이 단계는 Jenkins가 기본 체크아웃한 CI-CD 리포지토리에서 실행됨
                sshagent(credentials: [GITOPS_CREDENTIAL_ID]) {
                    sh """
                        # Git 사용자 설정
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins CI"

                        # Helm Chart의 values.yaml 수정
                        sed -i "s/tag: .*/tag: \\"${env.IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                        sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                        # 변경된 파일을 aws-test 브랜치에 커밋하고 푸시
                        git add helm-chart/my-web-app/values.yaml
                        git commit -m "Update image to ${env.IMAGE_NAME}"
                        git push origin HEAD:aws-test
                    """
                }
            }
        }
    }
}
