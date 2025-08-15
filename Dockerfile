# 1. Google Cloud SDK가 포함된 경량 Debian 기반 이미지 사용
FROM gcr.io/google.com/cloudsdktool/cloud-sdk:slim

# 2. root 사용자로 전환
USER root

# 3. 필요한 패키지 설치 (curl, tar, ca-certificates)
# Debian 기반이므로 apt-get 사용, 캐시 정리
RUN apt-get update && \
    apt-get install -y curl tar ca-certificates podman && \
    rm -rf /var/lib/apt/lists/*

# 4. podman을 docker 명령어처럼 사용할 수 있도록 심볼릭 링크 생성
RUN ln -s /usr/bin/podman /usr/bin/docker

# 5. Google Cloud SDK 환경 설정
# cloud-sdk 이미지에는 이미 gcloud, gsutil 포함
ENV PATH /google-cloud-sdk/bin:$PATH

