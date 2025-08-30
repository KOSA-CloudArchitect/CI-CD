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
                // ** 중요 **
                // web-server의 소스 코드를 별도로 체크아웃합니다.
                git branch: 'aws-test',
                    credentialsId: 'github-pat',
                    url: 'https://github.com/KOSA-CloudArchitect/web-server.git'
            }
        }

        stage('Build Application') {
            steps {
                // 2. 'maven' 컨테이너 안에서 빌드 명령어 실행
                container('maven') {
                    // web-server 프로젝트에 맞게 빌드 명령어를 수정해야 할 수 있습니다.
                    sh 'mvn clean package'
                }
            }
        }

        stage('Build & Push Container Image') {
            steps {
                // 3. 'podman' 컨테이너 안에서 이미지 빌드 및 푸시 실행
                container('podman') {
                    script {
                        def imageTag = "build-${BUILD_NUMBER}"
                        def fullImageName = "${ECR_REPOSITORY_URI}:${imageTag}"

                        // EC2에 연결된 IAM Role 권한으로 ECR에 로그인
                        // 'aws' 명령어 사용을 위해 aws-cli가 컨테이너 이미지에 설치되어 있어야 함
                        // quay.io/podman/stable 이미지에는 aws-cli가 없으므로,
                        // Pod Template의 podman 컨테이너 이미지를 aws-cli와 podman이 모두 포함된 이미지로 변경해야 할 수 있습니다.
                        sh "aws ecr get-login-password --region ${AWS_REGION} | podman login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                        sh "podman build -t ${fullImageName} ."
                        sh "podman push ${fullImageName}"

                        env.IMAGE_NAME = fullImageName
                    }
                }
            }
        }

        stage('Update Manifest') {
            steps {
                // 4. 이 단계는 CI-CD 리포지토리의 Helm Chart를 수정하고 Push
                // checkout scm을 통해 이미 CI-CD 리포지토리가 체크아웃된 상태
                script {
                   // checkout scm 이 아니라 현재 리포지토리의 내용을 수정해야함
                   // 이 부분은 Jenkins 가 git credential 을 가지고 있어야함
                   // checkout scm 을 사용하지 않았기 때문에 git push 권한이 없음
                   // 따라서 ssh-agent 를 사용해야함.
                    sshagent(credentials: ['gitops-repo-deploy-key']) {
                        sh """
                            # CI-CD 리포지토리를 다시 클론 (쓰기 권한을 위해)
                            git clone git@github.com:KOSA-CloudArchitect/CI-CD.git ci-cd-repo
                            cd ci-cd-repo
                            git checkout aws-test

                            # Helm Chart의 values.yaml 수정
                            sed -i "s/tag: .*/tag: \\"${env.IMAGE_NAME##*:}\\"/g" helm-chart/my-web-app/values.yaml
                            sed -i "s|repository:.*|repository: ${ECR_REPOSITORY_URI}|g" helm-chart/my-web-app/values.yaml

                            # Git 설정 및 Push
                            git config --global user.email "jenkins@example.com"
                            git config --global user.name "Jenkins CI"
                            git add helm-chart/my-web-app/values.yaml
                            git commit -m "Update image to ${env.IMAGE_NAME}"
                            git push origin aws-test
                        """
                    }
                }
            }
        }
    }
}
