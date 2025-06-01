# Stage 1: Setup - Install dependencies and perform initial build/download
FROM node:22 as setup
RUN apt-get update && apt-get install git -yq --no-install-suggests --no-install-recommends

WORKDIR /app
# 复制整个项目到 /app，包括 src, package.json 等
COPY . .

# 安装所有依赖。npm install 会触发 pre 脚本。
# 确保 pre.sh 将下载的 blocklists__ 和 dbip__ 放在 /app 目录下。
RUN npm install

# 显式创建这些目录，以防 pre.sh 没有创建，或者确保它们存在于正确的层。
# 这样做可以帮助解决 COPY 不找到目录的问题，如果它们是空的也会创建。
RUN mkdir -p ./blocklists__ ./dbip__

# 再次运行下载脚本以确保 blocklists 和 dbip 数据存在
# 假设 pre.sh 是下载这些数据的，并且它们会被放置在当前工作目录（/app）
# 如果 pre.sh 运行多次没有副作用，可以再次运行。
# 如果 pre.sh 只是 npm install 的 prepare 钩子，那么不需要再次运行。
# 我们需要确认 pre.sh 最终将文件放在哪里。
# 如果 pre.sh 会创建这些目录，并且将文件放入其中，那么上面 mkdir -p 可能不是必需的。
# 但为了调试，保留它。

# 在 setup 阶段查看文件，确认它们是否被下载到正确的位置
RUN ls -Fla /app/
RUN ls -Fla /app/blocklists__/
RUN ls -Fla /app/dbip__/


# Stage 2: Runner - The final, lean image for running the application
FROM node:22-alpine AS runner

ENV NODE_ENV production
ENV NODE_OPTIONS="--max-old-space-size=200 --heapsnapshot-signal=SIGUSR2"
ENV BLOCKLIST_DOWNLOAD_ONLY=false

WORKDIR /app

# 复制必要的 Node.js 模块
COPY --from=setup /app/node_modules ./node_modules/

# 复制应用程序源代码
COPY --from=setup /app/src ./src/

# 复制下载的数据目录
# 关键：确保这些目录在 setup 阶段的 /app 目录中确实存在
COPY --from=setup /app/blocklists__ ./blocklists__/
COPY --from=setup /app/dbip__ ./dbip__/

# 复制 package.json 和 package-lock.json (needed by npm start)
COPY --from=setup /app/package.json ./package.json
COPY --from=setup /app/package-lock.json ./package-lock.json


# 再次在 runner 阶段检查文件，确认它们是否被复制成功
RUN ls -Fla /app/
RUN ls -Fla /app/src/
RUN ls -Fla /app/blocklists__/
RUN ls -Fla /app/dbip__/


# 设置应用程序的入口点
ENTRYPOINT ["npm", "start"]
