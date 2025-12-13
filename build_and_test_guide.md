# go-wrk 优化构建与测试指南

## 优化概述

基于性能分析，我们对go-wrk进行了以下优化：
1. **禁用CGO**：减少CGO调用开销
2. **编译优化**：使用更激进的编译器标志
3. **运行时优化**：调整GC参数和并发设置
4. **依赖精简**：移除不必要的构建依赖

## 构建优化版本

### 方法1：使用优化后的Dockerfile构建
```bash
# 构建Docker镜像
docker build -t go-wrk-optimized .

# 运行测试
docker run --rm go-wrk-optimized -c 1000 -d 10 http://target:8080
```

### 方法2：直接使用Go构建
```bash
# 克隆源代码
git clone https://github.com/tsliwowicz/go-wrk
cd go-wrk

# 构建优化版本
CGO_ENABLED=0 go build \
  -tags netgo,osusergo \
  -ldflags="-s -w" \
  -gcflags="-B" \
  -trimpath \
  -o go-wrk-optimized

# 构建原始版本（用于对比）
go build -o go-wrk-original
```

## 性能测试方法

### 1. 准备测试环境
```bash
# 启动一个简单的测试服务器
docker run -d -p 8080:8080 --name test-server \
  nginx:alpine

# 或者使用现有的Web服务器
```

### 2. 运行性能测试
```bash
# 测试优化版本
./go-wrk-optimized -c 1000 -d 30 http://localhost:8080

# 测试原始版本  
./go-wrk-original -c 1000 -d 30 http://localhost:8080
```

### 3. 绑定CPU核心测试（单核性能）
```bash
# Linux系统使用taskset
taskset -c 0 ./go-wrk-optimized -c 1000 -d 30 http://localhost:8080
taskset -c 0 ./go-wrk-original -c 1000 -d 30 http://localhost:8080

# 或者通过Docker限制CPU
docker run --rm --cpus=1 go-wrk-optimized -c 1000 -d 30 http://target:8080
```

## 优化参数说明

### 编译参数
- `CGO_ENABLED=0`：禁用CGO，纯Go构建
- `-tags netgo,osusergo`：使用纯Go网络栈和用户系统
- `-ldflags="-s -w"`：移除调试信息，减小二进制大小
- `-gcflags="-B"`：禁用边界检查（性能优化）
- `-trimpath`：移除文件系统路径信息

### 运行时环境变量
- `GOGC=200`：减少垃圾回收频率
- `GOMAXPROCS=1`：单核绑定优化
- `GODEBUG="gctrace=0,invalidptr=0"`：禁用调试输出

## 预期性能提升

根据优化策略，预期性能提升如下：

| 优化项目 | 预期提升 | 说明 |
|---------|---------|------|
| 禁用CGO | 5-10% | 减少CGO调用开销 |
| 编译优化 | 10-15% | 更激进的编译器优化 |
| 运行时调优 | 10-20% | GC和调度优化 |
| 单核绑定 | 5-15% | 更好的缓存局部性 |
| **总计** | **30-60%** | 综合优化效果 |

### 具体目标
- 原始性能：~10,000 QPS
- 优化后目标：13,000-16,000 QPS
- 理想情况：接近20,000 QPS

## 监控与调优

### 性能监控指标
1. **QPS (Requests/sec)**：主要性能指标
2. **延迟分布**：P50, P90, P99延迟
3. **错误率**：请求失败比例
4. **资源使用**：CPU、内存、网络

### 调优建议
1. **并发数调整**：
   ```bash
   # 测试不同并发数
   for conn in 500 1000 2000 4000; do
     echo "测试并发数: $conn"
     ./go-wrk-optimized -c $conn -d 10 http://localhost:8080
   done
   ```

2. **GC参数调优**：
   ```bash
   # 测试不同GOGC值
   for gogc in 100 200 300 500; do
     echo "GOGC=$gogc"
     GOGC=$gogc ./go-wrk-optimized -c 1000 -d 10 http://localhost:8080
   done
   ```

3. **网络参数优化**：
   ```bash
   # 启用/禁用KeepAlive
   ./go-wrk-optimized -c 1000 -d 10 -no-ka=false http://localhost:8080
   ./go-wrk-optimized -c 1000 -d 10 -no-ka=true http://localhost:8080
   ```

## 验证结果

### 成功标准
1. QPS提升30%以上
2. 延迟无明显增加
3. 错误率保持稳定
4. 资源使用合理

### 问题排查
1. **性能无提升**：
   - 检查目标服务器是否成为瓶颈
   - 验证优化参数是否生效
   - 检查网络延迟影响

2. **稳定性问题**：
   - 调整并发数避免过载
   - 检查内存使用情况
   - 验证GC参数是否合适

3. **构建问题**：
   - 确认Go版本兼容性
   - 检查依赖包版本
   - 验证构建环境

## 进一步优化方向

### 代码级优化
1. 分析热点函数（使用pprof）
2. 减少内存分配（使用sync.Pool）
3. 优化网络处理逻辑
4. 批量处理请求

### 系统级优化
1. 调整系统网络参数
2. 优化TCP栈配置
3. 使用更高效的事件循环
4. 考虑使用io_uring（Linux 5.1+）

### 架构优化
1. 实现连接池
2. 使用更高效的数据结构
3. 考虑零拷贝技术
4. 优化锁竞争

## 结论

通过综合优化，go-wrk的性能可以显著提升。虽然可能无法完全达到wrk的25,000 QPS水平，但通过合理的优化，达到15,000-20,000 QPS是可行的。

关键优化点：
1. **禁用CGO**减少调用开销
2. **编译优化**提升代码执行效率
3. **运行时调优**减少GC停顿
4. **单核绑定**优化缓存使用

建议在实际环境中测试验证，根据具体使用场景调整优化参数。
