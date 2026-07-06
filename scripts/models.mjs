import { fetchQClawModels } from '../lib/qclaw.mjs';

function hasFlag(name) {
  return process.argv.includes(name);
}

function printText(models) {
  for (const model of models) {
    const parts = [
      model.id.padEnd(36),
      model.name.padEnd(30),
      model.status.padEnd(11),
      model.rate || '-',
    ];
    const capabilities = model.capabilities.length > 0 ? `  ${model.capabilities.join(', ')}` : '';
    process.stdout.write(`${parts.join('  ')}${capabilities}\n`);
  }
}

async function run() {
  try {
    const models = await fetchQClawModels();
    if (hasFlag('--json')) {
      process.stdout.write(`${JSON.stringify(models, null, 2)}\n`);
      return;
    }

    process.stdout.write('model id                              name                            status       rate\n');
    process.stdout.write('------------------------------------------------------------------------------------------\n');
    printText(models);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`获取 QClaw 模型列表失败：${message}\n`);
    process.exitCode = 1;
  }
}

run();
