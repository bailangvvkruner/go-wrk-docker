# Hugo Static Compilation Docker Build with BusyBox
# 使用 busybox:musl 作为基础镜像，提供基本shell环境

# 构建阶段 - 使用完整的构建环境
# FROM golang:1.21-alpine AS builder
FROM golang:alpine AS builder

WORKDIR /app

# 安装构建依赖（包括C++编译器和strip工具）
# 使用--no-scripts禁用触发器执行，避免busybox触发器在arm64架构下的兼容性问题
RUN set -eux && apk add --no-cache --no-scripts --virtual .build-deps \
    gcc \
    g++ \
    musl-dev \
    git \
    build-base \
    # 包含strip命令
    binutils \
    upx \
    # 直接下载并构建 go-wrk（无需本地源代码）
    # && git clone --depth 1 https://github.com/tsliwowicz/go-wrk . \
    && git clone --depth 1 https://github.com/bailangvvkg/go-wrk . \
    # 构建所有四个组件
    && echo "Building all four components..." \
    # 构建原始go-wrk
    && CGO_ENABLED=1 go build \
    -tags extended,netgo,osusergo \
    -ldflags="-s -w -extldflags -static" \
    -o go-wrk \
    go-wrk.go \
    && echo "go-wrk binary size:" \
    && du -b go-wrk \
    # 构建协调器
    && CGO_ENABLED=1 go build \
    -tags extended,netgo,osusergo \
    -ldflags="-s -w -extldflags -static" \
    -o go-wrk-coordinator \
    coordinator.go \
    && echo "go-wrk-coordinator binary size:" \
    && du -b go-wrk-coordinator \
    # 构建工作节点
    && CGO_ENABLED=1 go build \
    -tags extended,netgo,osusergo \
    -ldflags="-s -w -extldflags -static" \
    -o go-wrk-worker \
    worker.go \
    && echo "go-wrk-worker binary size:" \
    && du -b go-wrk-worker \
    # 构建分布式客户端
    && CGO_ENABLED=1 go build \
    -tags extended,netgo,osusergo \
    -ldflags="-s -w -extldflags -static" \
    -o go-wrk-dist \
    go-wrk-dist.go \
    && echo "go-wrk-dist binary size:" \
    && du -b go-wrk-dist \
    # 使用strip进一步减小所有二进制文件大小
    && echo "Stripping all binaries..." \
    && strip --strip-all go-wrk \
    && strip --strip-all go-wrk-coordinator \
    && strip --strip-all go-wrk-worker \
    && strip --strip-all go-wrk-dist \
    && echo "Binary sizes after stripping:" \
    && du -b go-wrk go-wrk-coordinator go-wrk-worker go-wrk-dist \
    # 使用upx压缩所有二进制文件
    && echo "Compressing with upx..." \
    && upx --best --lzma go-wrk \
    && upx --best --lzma go-wrk-coordinator \
    && upx --best --lzma go-wrk-worker \
    && upx --best --lzma go-wrk-dist \
    && echo "Final binary sizes:" \
    && du -b go-wrk go-wrk-coordinator go-wrk-worker go-wrk-dist
    # 注意：这里故意不清理构建依赖，因为是多阶段构建，且清理会触发busybox触发器错误
    # 最终镜像只复制二进制文件，构建阶段的中间层不会影响最终镜像大小
    # # 清理构建依赖
    # && apk del --purge .build-deps \
    # && rm -rf /var/cache/apk/*

# 运行时阶段 - 使用busybox:musl（极小的基础镜像，包含基本shell）
# FROM busybox:musl
# FROM alpine:latest
FROM scratch AS pod
# FROM hectorm/scratch:latest AS pod


# 复制CA证书（用于HTTPS请求）
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 复制所有四个二进制文件
COPY --from=builder /app/go-wrk /go-wrk
COPY --from=builder /app/go-wrk-coordinator /go-wrk-coordinator
COPY --from=builder /app/go-wrk-worker /go-wrk-worker
COPY --from=builder /app/go-wrk-dist /go-wrk-dist

# 创建非root用户（增强安全性）
# RUN adduser -D -u 1000 gowrk

# 设置工作目录
# WORKDIR /app

# 切换到非root用户
# USER gowrk

# Go 运行时优化：垃圾回收器（GC）调优
# GOGC 环境变量控制GC的频率。默认值是100，表示当堆大小翻倍时触发GC。
# 在内存充足的环境中，增大此值（例如 GOGC=200）可以减少GC的运行频率，
# 从而可能提升程序性能，但代价是消耗更多的内存。
# 您可以在 `docker run` 时通过 `-e GOGC=200` 来覆盖此默认设置。
# ENV GOGC=100

# 设置入口点（保持原始go-wrk作为默认入口点）
# ENTRYPOINT ["/go-wrk"]

# 不设置默认入口点，让用户自行选择要运行的组件
# 使用方法示例：
# docker run --rm bailangvvking/go-wrk:distributed /go-wrk -c 10 -d 10 http://example.com
# docker run --rm bailangvvking/go-wrk:distributed /go-wrk-coordinator -port 8080
# docker run --rm bailangvvking/go-wrk:distributed /go-wrk-worker -port 8081 -id worker1
# docker run --rm bailangvvking/go-wrk:distributed /go-wrk-dist -c 100 -d 30 -workers "localhost:8081" http://example.com
