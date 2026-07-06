import {
  fetchDailyTokenUsage,
  fetchQPointAccount,
  fetchQPointFlows,
  fetchUsageDetails,
  summarizeQPointFlows,
  summarizeUsageDetails,
} from '../lib/qclaw.mjs';

function readOption(name) {
  const prefix = `${name}=`;
  const inline = process.argv.find((arg) => arg.startsWith(prefix));
  if (inline) return inline.slice(prefix.length);

  const index = process.argv.indexOf(name);
  if (index >= 0) return process.argv[index + 1];
  return undefined;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function today() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function run() {
  try {
    const date = readOption('--date') || today();
    const page = Number(readOption('--page') || 1);
    const pageSize = Number(readOption('--page-size') || 20);
    const points = await fetchQPointAccount();
    const pointFlowDetails = await fetchQPointFlows({ page, pageSize });
    const pointFlows = summarizeQPointFlows(pointFlowDetails);
    const result = { points, pointFlows };
    if (hasFlag('--records')) {
      result.flows = pointFlowDetails?.flows || [];
    }

    if (hasFlag('--tokens')) {
      const daily = await fetchDailyTokenUsage();
      const details = await fetchUsageDetails({ startDate: date, endDate: date, page, pageSize });
      const usage = summarizeUsageDetails(details);
      result.tokenQuota = { date, daily, usage };
      if (hasFlag('--records')) {
        result.tokenRecords = details?.records || [];
      }
    }

    if (hasFlag('--json')) {
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
      return;
    }

    process.stdout.write(`points_balance: ${points.balance}\n`);
    process.stdout.write(`activity_points: ${points.activityPoints}\n`);
    process.stdout.write(`subscription_points: ${points.subscriptionPoints}\n`);
    process.stdout.write(`package_points: ${points.packagePoints}\n`);
    process.stdout.write(`total_daily_free_granted: ${points.totalDailyFreeGranted}\n`);
    process.stdout.write(`updated_at: ${points.updatedAt || '-'}\n`);
    process.stdout.write(`point_flows_total: ${pointFlows.totalFlows}\n`);
    process.stdout.write(`point_flows_page: ${pointFlows.page}\n`);
    process.stdout.write(`point_consumed_in_page: ${pointFlows.consumedInPage}\n`);
    process.stdout.write(`point_gained_in_page: ${pointFlows.gainedInPage}\n`);
    if (hasFlag('--tokens')) {
      const { daily, usage } = result.tokenQuota;
      const limit = Number(daily?.daily_token_limit) || 0;
      const used = Number(daily?.daily_token_used) || 0;
      const remaining = limit > 0 ? limit - used : undefined;
      process.stdout.write(`token_date: ${date}\n`);
      process.stdout.write(`daily_token_limit: ${limit}\n`);
      process.stdout.write(`daily_token_used: ${used}\n`);
      process.stdout.write(`daily_token_remaining: ${remaining ?? '-'}\n`);
      process.stdout.write(`rpm_limit: ${daily?.rpm_limit ?? '-'}\n`);
      process.stdout.write(`usage_records_total: ${usage.totalRecords}\n`);
      process.stdout.write(`usage_tokens_total_in_page: ${usage.totalTokens}\n`);
      process.stdout.write(`usage_cost_total_in_page: ${usage.cost}\n`);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`查询 QClaw 余额/用量失败：${message}\n`);
    process.exitCode = 1;
  }
}

run();
