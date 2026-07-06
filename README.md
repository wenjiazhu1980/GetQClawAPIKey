# GetQClawAPIKey

从已登录的本机 QClaw 客户端中提取明文 `apiKey` 的工具。提供 **Node.js CLI** 和 **macOS 菜单栏应用** 两种使用方式。

无需模拟登录或调用 QClaw 登录接口，只需在官方 QClaw 客户端完成一次登录/授权，即可读取本地存储的 provider key。

## 项目结构

```
├── lib/qclaw.mjs              # 核心库：解密、API 请求封装
├── scripts/
│   ├── get-key.mjs            # 提取并打印 apiKey
│   ├── models.mjs             # 查看可用模型列表
│   └── balance.mjs            # 查询积分余额和用量
├── test/qclaw.test.mjs        # 单元测试
├── GetQClaw-macOS/            # macOS 菜单栏应用（SwiftUI）
│   ├── Sources/               # Swift 源码
│   ├── build.sh               # 构建脚本
│   └── build/                 # 预构建的 .app 捆绑包
└── package.json
```

## 前置条件

- macOS
- 已安装 QClaw 客户端
- 已打开 QClaw 并完成一次登录/授权
- 运行时允许访问 macOS Keychain 中的 `QClaw Safe Storage`

## Node.js CLI

### 快速开始

```bash
npm install
npm start
```

仅打印 key，不输出 curl 示例：

```bash
node scripts/get-key.mjs --key-only
```

### 查看模型列表

```bash
npm run models
npm run models -- --json
```

### 查询积分余额和用量

```bash
npm run balance
npm run balance -- --json
npm run balance -- --json --records
npm run balance -- --page 2 --page-size 50
npm run balance -- --tokens
npm run balance -- --tokens --date 2026-06-29
```

默认输出：积分余额、活动积分、订阅积分、积分包余额、每日赠送总额、积分流水统计。

- `--records`：在 JSON 输出中包含原始流水明细
- `--tokens`：额外输出每日 token 配额和指定日期的用量汇总

### 运行测试

```bash
npm test
```

## macOS 菜单栏应用

一个原生 SwiftUI 菜单栏应用，在菜单栏显示 QClaw 图标，点击后可在 **API Key**、**模型列表**、**余额** 三个标签页间切换查看。

### 构建

```bash
cd GetQClaw-macOS
./build.sh
```

构建产物位于 `GetQClaw-macOS/build/GetQClaw.app`。

### 运行

```bash
open GetQClaw-macOS/build/GetQClaw.app
```

或拖入 `/Applications` 后从启动台打开。首次运行需要在 Keychain 弹窗中允许访问。

## 原理

QClaw 登录后将默认 provider 的 key 存在：

```text
~/Library/Application Support/QClaw/app-store.json
```

键路径：`authGateway.providers.qclaw.apiKey`

该值是 Chromium/Electron `v10` 格式密文。工具从 macOS Keychain 读取 `QClaw Safe Storage` / `QClaw Key`，使用 AES-128-CBC 解密后输出明文 key。

也可以通过环境变量覆盖路径：

```bash
QCLAW_APP_STORE_PATH=/path/to/app-store.json npm start
```

## API 用法

聊天补全接口地址：

```text
https://mmgrcalltoken.3g.qq.com/aizone/v1/chat/completions
```

示例请求：

```bash
curl --location --request POST 'https://mmgrcalltoken.3g.qq.com/aizone/v1/chat/completions' \
  -H 'Authorization: Bearer <YOUR_API_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "modelroute",
    "messages": [
      { "role": "system", "content": "hi" },
      { "role": "user", "content": "hi" }
    ]
  }'
```

注意：该网关兼容 OpenAI `chat/completions` 格式，但必须同时传递 `system` 和 `user` 消息，只传单条 `user` 消息会返回 `400 invalid request`。

### 可用模型

QClaw 客户端菜单里的具体模型在 API 中使用 `pool-` 前缀模型 ID；`modelroute` 是 Auto，不是具体模型。

该 API 当前所有可请求模型使用统一规格：上下文窗口 `200k`，最大输出 `8192` tokens。

当前已用本项目脚本和 QClaw key 实测 `chat/completions` 可返回 `200` 的具体模型：

| 显示名 | API model | 上下文 | 最大输出 |
| --- | --- | --- | --- |
| DeepSeek-V4-Pro | `pool-deepseek-v4-pro` | `200k` | `8192` |
| DeepSeek-V4-Flash | `pool-deepseek-v4-flash` | `200k` | `8192` |
| GLM-5.2 | `pool-glm-5.2` | `200k` | `8192` |
| Kimi-K2.7-Code-HighSpeed | `pool-kimi-k2.7-code-highspeed` | `200k` | `8192` |
| MiniMax-M3 | `pool-minimax-m3` | `200k` | `8192` |
| GLM-5.1 | `pool-glm-5.1` | `200k` | `8192` |
| Kimi-K2.6 | `pool-kimi-k2.6` | `200k` | `8192` |
| MiniMax-M2.7 | `pool-minimax-m2.7` | `200k` | `8192` |

`npm run models` 会直接调用 QClaw 客户端使用的模型列表接口，输出当前状态、倍率和能力标签。模型状态来自 QClaw 实时接口，可能随账号、地区和服务负载变化。

如果是在 OpenClaw 里配置 provider，`baseUrl` 应填写：

```text
https://mmgrcalltoken.3g.qq.com/aizone/v1
```

不要带 `/chat/completions`；OpenClaw 会自行拼接后续路径。

## 常见问题

### 提示未找到 app-store.json

先安装并打开 QClaw，完成一次登录/授权。

### 提示未找到 authGateway.providers.qclaw.apiKey

说明 QClaw 还没有把默认 provider key 写入本地存储。打开 QClaw，确认登录状态正常，并让客户端完成初始化。

### Keychain 弹出授权提示

允许终端/Node/macOS 应用访问 `QClaw Safe Storage`，否则无法解密本地密文。
