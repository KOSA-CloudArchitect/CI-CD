pipeline {
    // 1. EKS 위에 생성할 Pod 템플릿의 Label을 에이전트로 지정
    agent {
        label 'podman-maven-agent'
    }

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPOSITORY_URI = '833779331984.dkr.ecr.ap-northeast-2.amazonaws.com/web-server'
    }

    stages {
        stage('Checkout Application Code') {
            steps {
                // web-server의 소스 코드를 별도로 체크아웃
                git branch: 'aws-test',
                    credentialsId: 'github-pat',
                    url: 'https://github.com/KOSA-CloudArchitect/web-server.git'
            }
        }

        stage('Build Application') {
            steps {
                // 'maven' 컨테이너 안에서 빌드 명령어 실행
                container('maven') {
                    sh 'mvn clean package' // web-server 프로젝트에 맞게 수정
                }
            }
        }

        stage('Build & Push Container Image') {
            steps {
                // 'podman' 컨테이너 안에서 이미지 빌드 및 푸시 실행
                container('podman') {
                    script {
                        def imageTag = "build-${BUILD_NUMBER}"
                        def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"

                        sh "aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                        sh "podman build -t ${fullImageName} ."
                        sh "podman push ${fullImageName}"

                        // 다음 스테이지에서 사용할 수 있도록 변수 저장
                        env.IMAGE_NAME = fullImageName
                        env.IMAGE_TAG = imageTag
                    }
                }
            }
        }

        stage('Update Manifest') {
            steps {
                // checkout scm을 통해 CI-CD 리포지토리가 이미 체크아웃된 상태
                sh """
                    # Helm Chart의 values.yaml 수정
                    sed -i "s/tag: .*/tag: \\"${env.IMAGE_TAG}\\"/g" helm-chart/my-web-app/values.yaml
                    sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                    # Git 설정 및 Push
                    git config --global user.email "jenkins@example.com"
                    git config --global user.name "Jenkins CI"
                    git add helm-chart/my-web-app/values.yaml
                    git commit -m "Update image to ${env.IMAGE_NAME}"
                    git push origin HEAD:aws-test
                """
            }
        }
    }
}
