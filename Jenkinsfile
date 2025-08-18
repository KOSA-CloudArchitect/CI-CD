// Jenkinsfile (CI-CD 레포지토리용)

pipeline {
  agent { label 'podman-agent' }   // JCasC의 pod 템플릿 라벨과 동일해야 함

  environment {
    // GCP / Artifact Registry
    GCP_PROJECT_ID    = 'kwon-cicd'
    GCP_REGION        = 'asia-northeast3'
    GCR_REGISTRY_HOST = "${GCP_REGION}-docker.pkg.dev"
    GCR_REPO_PATH     = 'my-web-app-repo/web-server-backend'
    IMAGE             = "${GCR_REGISTRY_HOST}/${GCP_PROJECT_ID}/${GCR_REPO_PATH}"
    IMAGE_TAG         = "${env.BUILD_NUMBER}"

    // GitHub & Helm
    HELM_CHART_PATH   = 'helm-chart/my-web-app'
    GITHUB_ORG        = 'KOSA-CloudArchitect'
    GITHUB_REPO_WEB   = 'web-server'
    GITHUB_REPO_CICD  = 'CI-CD'
    GITHUB_USER       = 'kwon0905'
  }


  stages {
    stage('Preflight (환경 확인)') {
      steps {
        container('podman-agent') {
          sh '''
            set -eu
            echo "== Who am I =="; whoami || true
            echo "== HOME =="; echo "$HOME"
            echo "== Podman =="; podman --version
            echo "== gcloud =="; gcloud --version
          '''
        }
      }
    }

    stage('Checkout Web-Server Code') {
      steps {
        withCredentials([string(credentialsId: 'github-pat-for-cicd-job', variable: 'PAT')]) {
          sh '''
            set -eu
            rm -rf "${GITHUB_REPO_WEB}" || true
            git clone https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_WEB}.git
          '''
        }
      }
    }

    stage('Authenticate to Artifact Registry (Podman)') {
      steps {
        container('podman-agent') {
          sh '''
            set -eu
            # JCasC에서 /home/jenkins/.gcp/key.json 로 Secret 마운트되어 있음
            KEY_FILE="/home/jenkins/.gcp/key.json"

            echo "== Activate service account =="
            gcloud auth activate-service-account --key-file="$KEY_FILE"

            echo "== Podman login to Artifact Registry (oauth2 token) =="
            TOKEN="$(gcloud auth print-access-token)"
            # scheme 없이 호스트만 쓰는 게 안전합니다.
            echo "$TOKEN" | podman login \
              -u oauth2accesstoken --password-stdin \
              ${GCR_REGISTRY_HOST}

            echo "Login done for ${GCR_REGISTRY_HOST}"
          '''
        }
      }
    }

    stage('Build & Push Docker Image (Podman)') {
      steps {
        container('podman-agent') {
          dir("${GITHUB_REPO_WEB}/backend") {
            sh '''
              set -eu
              FULL_IMAGE="${IMAGE}:${IMAGE_TAG}"
              echo "== Build image =="
              podman build -t "${FULL_IMAGE}" .

              echo "== Push image =="
              # 일시적 에러 대비하여 2회 재시도
              n=0
              until [ $n -ge 3 ]; do
                if podman push "${FULL_IMAGE}"; then
                  break
                fi
                n=$((n+1))
                echo "Push failed... retry $n/3 in 5s"
                sleep 5
              done
            '''
          }
        }
      }
    }

    stage('Update Helm values & Push to CI-CD Repo') {
      steps {
        container('podman-agent') {
          sh '''
            set -eu
            git config user.email "jenkins@${GITHUB_ORG}.com"
            git config user.name  "Jenkins CI Automation"

            # values.yaml 의 tag 필드만 교체
            sed -i "s|^\\s*tag:\\s*.*|    tag: \\"${IMAGE_TAG}\\"|g" "${HELM_CHART_PATH}/values.yaml"

            # 변경이 있는 경우에만 커밋/푸시
            if ! git diff --quiet -- "${HELM_CHART_PATH}/values.yaml"; then
              git add "${HELM_CHART_PATH}/values.yaml"
              git commit -m "Update image tag to ${IMAGE_TAG} by Jenkins build #${IMAGE_TAG}"
              echo "Committing image tag bump to CI-CD repo..."
              :
            else
              echo "No diff in values.yaml; skipping commit."
            fi
          '''

          withCredentials([string(credentialsId: 'github-pat-token', variable: 'PAT')]) {
            sh '''
              set -eu
              if git log -1 --pretty=%B | grep -q "Update image tag to ${IMAGE_TAG}"; then
                echo "Pushing commit..."
                git push "https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_ORG}/${GITHUB_REPO_CICD}.git" HEAD:main
              else
                echo "No commit to push."
              fi
            '''
          }
        }
      }
    }
  }

  post {
    always {
      script {
        // Workspace Cleanup 플러그인이 없는 경우에도 실패하지 않도록 처리
        try {
          cleanWs()
        } catch (err) {
          echo "cleanWs() unavailable -> fallback to deleteDir()"
          deleteDir()
        }
      }
    }
    failure {
      echo 'CI/CD Pipeline failed!'
    }
    success {
      echo "CI/CD Pipeline completed successfully! Image: ${IMAGE}:${IMAGE_TAG}"
      echo 'Argo CD가 해당 Helm 차트를 감시 중이라면 자동 배포됩니다.'
    }
  }
}

