# 1단계: 빌드 환경 구성
FROM node:18-slim AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# 2단계: 최종 실행 환경 구성
FROM node:18-slim
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/package*.json ./
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/dist ./dist
EXPOSE 8080
CMD [ "node", "dist/index.js" ]
