# Stage 1: Setup - 安装依赖 (和原来类似)
FROM node:22 as setup
RUN apt-get update && apt-get install git -yq --no-install-suggests --no-install-recommends
WORKDIR /app
COPY . .
RUN npm i

# 如果需要下载 blocklists 并在构建时烘焙，确保这个步骤能找到正确的入口文件
# 假设 `src/server-node.js` 可以通过设置环境变量来执行下载操作
# 注意：BLOCKLIST_DOWNLOAD_ONLY=true 应该只在构建阶段使用，运行时不能有
RUN export BLOCKLIST_DOWNLOAD_ONLY=true && node ./src/server-node.js
# 你可能需要验证 `serverless-dns` 的 `server-node.js` 是否支持 BLOCKLIST_DOWNLOAD_ONLY
# 或者这个 blocklist 下载逻辑可能在其他地方，需要确认
# 如果 `server-node.js` 不支持，你可能需要找到项目中专门用于下载 blocklist 的脚本

# Stage 2: Runner - 运行阶段
FROM node:22-alpine AS runner

ENV NODE_ENV production
ENV NODE_OPTIONS="--max-old-space-size=200 --heapsnapshot-signal=SIGUSR2"
# 确保 BLOCKLIST_DOWNLOAD_ONLY 变量在运行阶段为 false 或不设置
ENV BLOCKLIST_DOWNLOAD_ONLY=false

WORKDIR /app

# 复制 Stage 1 中安装的 node_modules (如果需要)
# 但是，如果你的 @riaskov/mmap-io 依赖在 alpine 镜像上需要重新编译
# 那么可能需要将 npm i @riaskov/mmap-io@v1.4.3 放到这里。
# 通常，如果安装到 /app/node_modules，这一行就足以复制过来
COPY --from=setup /app/node_modules ./node_modules
# 复制应用程序源代码和静态文件
COPY --from=setup /app/src ./src
COPY --from=setup /app/blocklists__ ./blocklists__
COPY --from=setup /app/dbip__ ./dbip__
COPY --from=setup /app/package.json ./package.json # 复制 package.json 以便 npm start

# 再次验证文件是否存在 (仅用于调试，成功后可删除)
RUN ls -Fla /app
RUN ls -Fla /app/src

# 修正 CMD 命令，使用项目实际的启动文件
# 根据 serverless-dns 的 package.json，"start": "node src/server-node.js"
CMD ["npm", "start"]
# 或者直接运行入口文件
# CMD ["node", "./src/server-node.js"]
