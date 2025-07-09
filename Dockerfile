# 使用官方 Node.js 18 Alpine 镜像
FROM node:18-alpine
# 安装所需工具
RUN apk add --no-cache tini git
# 设置工作目录
WORKDIR /app
# 在构建时完成所有重型工作
RUN git clone -b staging --depth 1 https://github.com/SillyTavern/SillyTavern.git .
RUN npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev --force && npm cache clean --force
RUN node docker/build-lib.js
# 复制我们最终的启动脚本
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
# 设置入口点
EXPOSE 8000
ENTRYPOINT ["/sbin/tini", "--", "/app/start.sh"]
