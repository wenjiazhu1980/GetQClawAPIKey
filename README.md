# GetQClawAPIKey

从已登录的本机 QClaw 中提取并打印明文 `apiKey` 的本地 Node CLI。

这个项目现在不再模拟 QClaw 微信扫码登录，也不再调用 QClaw 登录接口。你需要先在官方 QClaw 客户端里完成一次登录/授权；脚本随后读取 QClaw 保存到本机的 provider key。

## Quick Start

```bash
npm install
npm start
```

仅打印 key，不输出 `curl` 示例：

```bash
node scripts/get-key.mjs --key-only
```

查看 QClaw 当前模型列表：

```bash
npm run models
```

查询每日额度和当天用量汇总：

```bash
npm run balance
```

## 前置条件

- macOS
- 已安装 QClaw
- 已打开 QClaw 并完成一次登录/授权
- 运行脚本时允许访问 macOS Keychain 中的 `QClaw Safe Storage`

脚本默认读取：

```text
~/Library/Application Support/QClaw/app-store.json
```

也可以通过环境变量覆盖：

```bash
QCLAW_APP_STORE_PATH=/path/to/app-store.json npm start
```

## 原理

QClaw 登录后会把默认 provider 的 key 存在 `app-store.json`：

```text
authGateway.providers.qclaw.apiKey
```

该值通常是 Chromium/Electron `v10` 格式密文。脚本会从 macOS Keychain 读取 `QClaw Safe Storage` / `QClaw Key`，然后解密并打印明文 key。

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

注意：该网关虽然兼容 OpenAI `chat/completions` 格式，但只传单条 `user` 消息会返回 `400 invalid request`。示例中保留了一条最小 `system` 消息用于验证。

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

`npm run models` 会直接调用 QClaw 客户端使用的模型列表接口，并输出当前状态、倍率和能力标签：

```bash
npm run models
npm run models -- --json
```

模型状态来自 QClaw 实时接口，可能随账号、地区和服务负载变化。比如 `pool-glm-5.2` 在菜单中可能显示 `full`，但实际网关请求仍可能成功。

`pool-hy3-preview` 会出现在模型列表中，但本次用同一 `chat/completions` 请求实测返回 `400 proxy_param_error`，因此暂不列入上面的可用模型表。

如果是在 OpenClaw 里配置 provider，`baseUrl` 应填写：

```text
https://mmgrcalltoken.3g.qq.com/aizone/v1
```

不要带 `/chat/completions`；OpenClaw 会自行拼接后续路径。

## 积分余额和用量

```bash
npm run balance
```

默认输出：

- `points_balance`：当前总积分余额
- `activity_points`：活动积分，等于 QClaw 返回的 `daily_free + activity_q`
- `subscription_points`：订阅积分
- `package_points`：积分包余额
- `total_daily_free_granted`：活动/每日赠送积分总额
- `point_flows_total`：积分流水总条数
- `point_consumed_in_page`：当前页积分消耗合计
- `point_gained_in_page`：当前页积分收入合计

可选参数：

```bash
npm run balance -- --json
npm run balance -- --json --records
npm run balance -- --page 2 --page-size 50
npm run balance -- --tokens
npm run balance -- --tokens --date 2026-06-29
```

默认不会打印积分流水明细；只有显式加 `--records` 才会在 JSON 输出中包含原始流水。`--tokens` 会额外输出旧的每日 token quota 和指定日期 token 用量明细汇总。

## 常见问题

### 提示未找到 app-store.json

先安装并打开 QClaw，完成一次登录/授权。

### 提示未找到 authGateway.providers.qclaw.apiKey

说明 QClaw 还没有把默认 provider key 写入本地存储。打开 QClaw，确认登录状态正常，并让客户端完成初始化。

### Keychain 弹出授权提示

允许终端或 Node 访问 `QClaw Safe Storage`，否则无法解密本地密文。
