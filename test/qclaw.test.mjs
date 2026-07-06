import assert from 'node:assert/strict';
import test from 'node:test';

import {
  extractRespData,
  normalizeQPointAccount,
  normalizeModelRows,
  summarizeQPointFlows,
  summarizeUsageDetails,
} from '../lib/qclaw.mjs';

test('extractRespData reads QClaw JPrx nested response data', () => {
  const payload = {
    ret: 0,
    data: {
      resp: {
        common: { code: 0, message: 'Success' },
        data: { ok: true },
      },
    },
  };

  assert.deepEqual(extractRespData(payload), { ok: true });
});

test('normalizeModelRows maps status and rate information', () => {
  const rows = normalizeModelRows(
    [
      { id: 'default', name: 'Auto', status_level: 0 },
      { id: 'pool-glm-5.2', name: 'GLM-5.2', status_level: 2 },
    ],
    [
      { model_id: 'default', rate_multiplier: 'x1.0' },
      { model_id: 'pool-glm-5.2', rate_multiplier: 'x2.5' },
    ],
  );

  assert.deepEqual(rows, [
    { id: 'modelroute', name: 'Auto', status: 'available', rate: 'x1.0', capabilities: [] },
    { id: 'pool-glm-5.2', name: 'GLM-5.2', status: 'full', rate: 'x2.5', capabilities: [] },
  ]);
});

test('summarizeUsageDetails totals usage records', () => {
  const summary = summarizeUsageDetails({
    total: 2,
    records: [
      { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15, cost: 0.1 },
      { prompt_tokens: 20, completion_tokens: 7, total_tokens: 27, cost: 0.2 },
    ],
  });

  assert.deepEqual(summary, {
    totalRecords: 2,
    promptTokens: 30,
    completionTokens: 12,
    totalTokens: 42,
    cost: 0.3,
  });
});

test('normalizeQPointAccount maps point balance details', () => {
  const account = normalizeQPointAccount({
    balance: 798.27553,
    total_daily_free_granted: 800,
    updated_at: '2026-05-09T01:50:12+08:00',
    balance_detail: {
      daily_free: 798.27553,
      activity_q: 1,
      subscription_q: 2,
      package_q: 3,
      items: [{ label: '活动赠送', remain_amount: 798.27553 }],
    },
  });

  assert.deepEqual(account, {
    balance: 798.27553,
    activityPoints: 799.27553,
    subscriptionPoints: 2,
    packagePoints: 3,
    totalDailyFreeGranted: 800,
    updatedAt: '2026-05-09T01:50:12+08:00',
    items: [{ label: '活动赠送', remain_amount: 798.27553 }],
  });
});

test('summarizeQPointFlows totals point flow page', () => {
  const summary = summarizeQPointFlows({
    total: 3,
    page: 1,
    page_size: 2,
    flows: [
      { direction: 2, amount: 0.1 },
      { direction: 1, amount: 2 },
    ],
  });

  assert.deepEqual(summary, {
    totalFlows: 3,
    page: 1,
    pageSize: 2,
    flowCountInPage: 2,
    consumedInPage: 0.1,
    gainedInPage: 2,
  });
});
