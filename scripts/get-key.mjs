import { readQClawApiKey } from '../lib/qclaw.mjs';

function timestamp() {
  return new Date().toLocaleTimeString('zh-CN', { hour12: false });
}

function log(message) {
  process.stdout.write(`[${timestamp()}] ${message}\n`);
}

function printCurlExample(apiKey) {
  process.stdout.write(
    `\n` +
      `curl --location --request POST 'https://mmgrcalltoken.3g.qq.com/aizone/v1/chat/completions' \\\n` +
      `  -H 'Authorization: Bearer ${apiKey}' \\\n` +
      `  -H 'Content-Type: application/json' \\\n` +
      `  -d '{\n` +
      `    "model": "modelroute",\n` +
      `    "messages": [\n` +
      `      { "role": "system", "content": "hi" },\n` +
      `      { "role": "user", "content": "hi" }\n` +
      `    ]\n` +
      `  }'\n`
  );
}

function run() {
  try {
    const apiKey = readQClawApiKey();
    log('已从已登录的 QClaw 本地存储读取 apiKey。');
    process.stdout.write(`${apiKey}\n`);

    if (!process.argv.includes('--key-only')) {
      printCurlExample(apiKey);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    log(`读取 QClaw apiKey 失败：${message}`);
    process.exitCode = 1;
  }
}

run();
