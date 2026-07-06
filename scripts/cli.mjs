import * as readline from 'node:readline';
import {
  readQClawApiKey,
  fetchQClawModels,
  fetchQPointAccount,
  fetchQPointFlows,
  fetchDailyTokenUsage,
  fetchUsageDetails,
  summarizeQPointFlows,
  summarizeUsageDetails,
} from '../lib/qclaw.mjs';

// --------------- helpers ---------------

function today() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';
const RESET = '\x1b[0m';
const CLEAR = '\x1b[2J\x1b[H';

function box(title, lines) {
  const width = 56;
  const top = `\u250c${'\u2500'.repeat(width - 2)}\u2510`;
  const sep = `\u251c${'\u2500'.repeat(width - 2)}\u2524`;
  const bot = `\u2514${'\u2500'.repeat(width - 2)}\u2518`;
  process.stdout.write(CLEAR);
  process.stdout.write(`${top}\n`);
  process.stdout.write(`\u2502  ${BOLD}${title.padEnd(width - 6)}${RESET}\u2502\n`);
  process.stdout.write(`${sep}\n`);
  for (const line of lines) {
    process.stdout.write(`\u2502  ${line.padEnd(width - 6)}\u2502\n`);
  }
  process.stdout.write(`${bot}\n`);
}

// --------------- TUI menu ---------------

function showMenu() {
  box('GetQClaw CLI', [
    `${CYAN}1${RESET}. Extract API Key`,
    `${CYAN}2${RESET}. View Available Models`,
    `${CYAN}3${RESET}. Check Balance & Usage`,
    '',
    `${DIM}0. Exit${RESET}`,
  ]);
  process.stdout.write(`\n  Choose [1-3 / 0]: `);
}

// --------------- action handlers ---------------

function handleKey(opts) {
  const keyOnly = opts.includes('--key-only');
  process.stdout.write(CLEAR);
  try {
    const apiKey = readQClawApiKey();
    process.stdout.write(`${GREEN}API Key:${RESET}\n\n`);
    process.stdout.write(`${apiKey}\n`);

    if (!keyOnly) {
      process.stdout.write(`\n${DIM}curl example:${RESET}\n`);
      process.stdout.write(
        `curl -X POST 'https://mmgrcalltoken.3g.qq.com/aizone/v1/chat/completions' \\\n` +
          `  -H 'Authorization: Bearer ${apiKey}' \\\n` +
          `  -H 'Content-Type: application/json' \\\n` +
          `  -d '{"model":"modelroute","messages":[{"role":"system","content":"hi"},{"role":"user","content":"hi"}]}'\n`
      );
    }
  } catch (e) {
    process.stdout.write(`${YELLOW}Error: ${e.message}${RESET}\n`);
  }
}

async function handleModels(opts) {
  const asJson = opts.includes('--json');
  process.stdout.write(CLEAR);
  try {
    const models = await fetchQClawModels();
    if (asJson) {
      process.stdout.write(JSON.stringify(models, null, 2) + '\n');
      return;
    }
    process.stdout.write(`${GREEN}Available Models:${RESET}\n\n`);
    const header = `${'ID'.padEnd(34)}  ${'Name'.padEnd(26)}  ${'Status'.padEnd(10)}  Rate`;
    process.stdout.write(`${header}\n${'\u2500'.repeat(header.length)}\n`);
    for (const m of models) {
      const caps = m.capabilities.length > 0 ? `  ${DIM}${m.capabilities.join(', ')}${RESET}` : '';
      process.stdout.write(
        `${m.id.padEnd(34)}  ${m.name.padEnd(26)}  ${m.status.padEnd(10)}  ${m.rate || '-'}${caps}\n`
      );
    }
  } catch (e) {
    process.stdout.write(`${YELLOW}Error: ${e.message}${RESET}\n`);
  }
}

async function handleBalance(opts) {
  const asJson = opts.includes('--json');
  const withRecords = opts.includes('--records');
  const withTokens = opts.includes('--tokens');
  const date = opts.find((o) => o.startsWith('--date='))?.split('=')[1] || today();
  const page = Number(opts.find((o) => o.startsWith('--page='))?.split('=')[1] || 1);
  const pageSize = Number(opts.find((o) => o.startsWith('--page-size='))?.split('=')[1] || 20);

  process.stdout.write(CLEAR);
  try {
    const points = await fetchQPointAccount();
    const flowDetails = await fetchQPointFlows({ page, pageSize });
    const flows = summarizeQPointFlows(flowDetails);

    if (asJson) {
      const result = { points, pointFlows: flows };
      if (withRecords) result.flows = flowDetails?.flows || [];
      if (withTokens) {
        const daily = await fetchDailyTokenUsage();
        const usageDetails = await fetchUsageDetails({ startDate: date, endDate: date, page, pageSize });
        result.tokenQuota = { date, daily, usage: summarizeUsageDetails(usageDetails) };
        if (withRecords) result.tokenRecords = usageDetails?.records || [];
      }
      process.stdout.write(JSON.stringify(result, null, 2) + '\n');
      return;
    }

    process.stdout.write(`${GREEN}Balance & Usage:${RESET}\n\n`);
    const rows = [
      ['Points Balance', String(points.balance)],
      ['Activity Points', String(points.activityPoints)],
      ['Subscription Points', String(points.subscriptionPoints)],
      ['Package Points', String(points.packagePoints)],
      ['Total Daily Free Granted', String(points.totalDailyFreeGranted)],
      ['Updated At', points.updatedAt || '-'],
      ['Flow Total', String(flows.totalFlows)],
      ['Consumed (page)', String(flows.consumedInPage)],
      ['Gained (page)', String(flows.gainedInPage)],
    ];
    for (const [label, value] of rows) {
      process.stdout.write(`  ${DIM}${label.padEnd(28)}${RESET} ${value}\n`);
    }

    if (withTokens) {
      const daily = await fetchDailyTokenUsage();
      const usageDetails = await fetchUsageDetails({ startDate: date, endDate: date, page, pageSize });
      const usage = summarizeUsageDetails(usageDetails);
      const limit = Number(daily?.daily_token_limit) || 0;
      const used = Number(daily?.daily_token_used) || 0;
      process.stdout.write(`\n${GREEN}Token Usage (${date}):${RESET}\n\n`);
      process.stdout.write(`  ${DIM}Daily Limit${RESET}      ${limit}\n`);
      process.stdout.write(`  ${DIM}Daily Used${RESET}       ${used}\n`);
      process.stdout.write(`  ${DIM}Remaining${RESET}        ${limit > 0 ? limit - used : '-'}\n`);
      process.stdout.write(`  ${DIM}RPM Limit${RESET}        ${daily?.rpm_limit ?? '-'}\n`);
      process.stdout.write(`  ${DIM}Usage Records${RESET}     ${usage.totalRecords}\n`);
      process.stdout.write(`  ${DIM}Tokens (page)${RESET}     ${usage.totalTokens}\n`);
      process.stdout.write(`  ${DIM}Cost (page)${RESET}       ${usage.cost}\n`);
    }
  } catch (e) {
    process.stdout.write(`${YELLOW}Error: ${e.message}${RESET}\n`);
  }
}

// --------------- interactive loop ---------------

function waitForEnter() {
  return new Promise((resolve) => {
    process.stdout.write(`\n${DIM}Press Enter to continue...${RESET}`);
    process.stdin.once('data', () => resolve());
  });
}

function ask() {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question('', (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function runInteractive() {
  while (true) {
    showMenu();
    const choice = await ask();

    switch (choice) {
      case '1':
        handleKey([]);
        await waitForEnter();
        break;
      case '2':
        await handleModels([]);
        await waitForEnter();
        break;
      case '3':
        await handleBalance([]);
        await waitForEnter();
        break;
      case '0':
        process.stdout.write(CLEAR + 'Bye.\n');
        return;
      default:
        process.stdout.write(`${YELLOW}Invalid choice.${RESET}\n`);
        await waitForEnter();
    }
  }
}

// --------------- entry ---------------

const args = process.argv.slice(2);

if (args.length === 0) {
  // Interactive TUI mode
  runInteractive().catch((e) => {
    process.stderr.write(`Fatal: ${e.message}\n`);
    process.exit(1);
  });
} else {
  // CLI subcommand mode
  const [cmd, ...opts] = args;
  (async () => {
    try {
      switch (cmd) {
        case 'key':
          handleKey(opts);
          break;
        case 'models':
          await handleModels(opts);
          break;
        case 'balance':
          await handleBalance(opts);
          break;
        default:
          process.stdout.write(`Usage: get-qclaw [key|models|balance] [options]\n`);
          process.exitCode = 1;
      }
    } catch (e) {
      process.stderr.write(`Error: ${e.message}\n`);
      process.exitCode = 1;
    }
  })();
}
