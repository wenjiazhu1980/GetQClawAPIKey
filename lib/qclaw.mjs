import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const QCLAW_APP_STORE_PATH = path.join(
  os.homedir(),
  'Library',
  'Application Support',
  'QClaw',
  'app-store.json'
);
const QCLAW_API_KEY_STORE_KEY = 'authGateway.providers.qclaw.apiKey';
const QCLAW_USER_INFO_STORE_KEY = 'secure.userInfo';
const QCLAW_JWT_TOKEN_STORE_KEY = 'secure.jwtToken';
const QCLAW_KEYCHAIN_SERVICE = 'QClaw Safe Storage';
const QCLAW_KEYCHAIN_ACCOUNT = 'QClaw Key';
const QCLAW_JPRX_GATEWAY = 'https://jprx.m.qq.com/';

function readJsonFile(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function getAppStorePath() {
  return process.env.QCLAW_APP_STORE_PATH || QCLAW_APP_STORE_PATH;
}

function getKeychainPassword() {
  return execFileSync(
    'security',
    [
      'find-generic-password',
      '-w',
      '-s',
      QCLAW_KEYCHAIN_SERVICE,
      '-a',
      QCLAW_KEYCHAIN_ACCOUNT,
    ],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }
  ).trim();
}

function decryptChromiumV10(cipherText, password) {
  const encrypted = Buffer.from(cipherText, 'base64');
  const prefix = encrypted.slice(0, 3).toString('utf8');
  if (prefix !== 'v10') {
    throw new Error(`不支持的 QClaw 本地密文格式: ${prefix || '<empty>'}`);
  }

  const key = crypto.pbkdf2Sync(password, 'saltysalt', 1003, 16, 'sha1');
  const iv = Buffer.alloc(16, ' ');
  const decipher = crypto.createDecipheriv('aes-128-cbc', key, iv);
  return Buffer.concat([
    decipher.update(encrypted.slice(3)),
    decipher.final(),
  ]).toString('utf8');
}

function decryptStoredValue(storedValue, password = getKeychainPassword()) {
  if (typeof storedValue === 'string') {
    return storedValue.trim();
  }

  if (!storedValue || typeof storedValue !== 'object') {
    return '';
  }

  if (typeof storedValue.value === 'string') {
    return storedValue.value.trim();
  }

  if (typeof storedValue.cipherText !== 'string') {
    return '';
  }

  return decryptChromiumV10(storedValue.cipherText, password).trim();
}

function readQClawStore() {
  if (process.platform !== 'darwin') {
    throw new Error('当前只支持 macOS：QClaw 的本地密钥保存在 macOS Keychain 中。');
  }

  const appStorePath = getAppStorePath();
  if (!fs.existsSync(appStorePath)) {
    throw new Error(
      `未找到 QClaw 本地存储文件：${appStorePath}\n` +
        '请先安装并打开 QClaw，完成一次登录/授权。'
    );
  }

  return readJsonFile(appStorePath);
}

function readQClawApiKey() {
  const store = readQClawStore();
  const apiKey = decryptStoredValue(store[QCLAW_API_KEY_STORE_KEY]);
  if (!apiKey) {
    throw new Error(
      `未在 QClaw 本地存储中找到 ${QCLAW_API_KEY_STORE_KEY}。\n` +
        '请先在 QClaw 中完成登录，并让 QClaw 初始化默认 provider。'
    );
  }

  return apiKey;
}

function readQClawAuthSession() {
  const store = readQClawStore();
  const password = getKeychainPassword();
  const rawUserInfo = decryptStoredValue(store[QCLAW_USER_INFO_STORE_KEY], password);
  if (!rawUserInfo) {
    throw new Error(`未在 QClaw 本地存储中找到 ${QCLAW_USER_INFO_STORE_KEY}。`);
  }

  const userInfo = JSON.parse(rawUserInfo);
  const jwtToken = decryptStoredValue(store[QCLAW_JWT_TOKEN_STORE_KEY], password);
  return { userInfo, jwtToken };
}

function buildCommonHeaders(session) {
  const { userInfo, jwtToken } = session;
  return {
    'Content-Type': 'application/json',
    'X-Version': '1',
    'X-Token': userInfo.loginKey || '',
    'X-Guid': userInfo.guid || '1',
    'X-Account': userInfo.userId || '1',
    'X-Session': '',
    ...(jwtToken ? { 'X-OpenClaw-Token': jwtToken } : {}),
    'X-Qclaw-DeviceToken': userInfo.guid || '',
  };
}

async function qclawCommonFetch(endpoint, payload = {}, session = readQClawAuthSession()) {
  const url = new URL(endpoint, QCLAW_JPRX_GATEWAY).toString();
  const body = JSON.stringify({
    ...payload,
    web_version: '1.4.0',
    web_env: 'release',
  });

  const response = await fetch(url, {
    method: 'POST',
    headers: buildCommonHeaders(session),
    body,
  });
  const text = await response.text();
  const parsed = text ? JSON.parse(text) : null;
  return {
    ok: response.ok,
    status: response.status,
    payload: parsed,
  };
}

function extractRespCommon(payload) {
  return (
    payload?.data?.resp?.common ||
    payload?.data?.common ||
    payload?.resp?.common ||
    payload?.common ||
    null
  );
}

function extractRespData(payload) {
  return (
    payload?.data?.resp?.data ??
    payload?.data?.data ??
    payload?.resp?.data ??
    payload?.data ??
    null
  );
}

function assertQClawSuccess(result, endpoint) {
  if (!result.ok) {
    throw new Error(`${endpoint} HTTP ${result.status}`);
  }

  const common = extractRespCommon(result.payload);
  if (common && common.code !== 0) {
    throw new Error(`${endpoint} code=${common.code} message=${common.message || '业务请求失败'}`);
  }
}

function statusName(statusLevel) {
  if (statusLevel === 1) return 'busy';
  if (statusLevel === 2) return 'full';
  if (statusLevel === 3) return 'unavailable';
  return 'available';
}

function normalizeModelRows(modelRows, rateRows = []) {
  const rates = new Map(rateRows.map((rate) => [rate.model_id, rate.rate_multiplier]));
  return modelRows.map((model) => {
    const id = model.id === 'default' ? 'modelroute' : model.id;
    return {
      id,
      name: model.name,
      status: statusName(model.status_level),
      rate: rates.get(model.id),
      capabilities: Array.isArray(model.capabilities) ? model.capabilities : [],
    };
  });
}

async function fetchQClawModels() {
  const session = readQClawAuthSession();
  const modelsResult = await qclawCommonFetch('data/4320/forward', {}, session);
  assertQClawSuccess(modelsResult, 'data/4320/forward');
  const modelRows = extractRespData(modelsResult.payload)?.model_status_list;
  if (!Array.isArray(modelRows)) {
    throw new Error('模型列表响应中没有 model_status_list。');
  }

  const modelIds = modelRows.map((model) => model.id).filter(Boolean);
  let rateRows = [];
  if (modelIds.length > 0) {
    const ratesResult = await qclawCommonFetch('data/4327/forward', { model_ids: modelIds }, session);
    if (ratesResult.ok) {
      const ratesCommon = extractRespCommon(ratesResult.payload);
      if (!ratesCommon || ratesCommon.code === 0) {
        const rows = extractRespData(ratesResult.payload)?.rates;
        rateRows = Array.isArray(rows) ? rows : [];
      }
    }
  }

  return normalizeModelRows(modelRows, rateRows);
}

async function fetchDailyTokenUsage() {
  const result = await qclawCommonFetch('data/4075/forward', {});
  assertQClawSuccess(result, 'data/4075/forward');
  return extractRespData(result.payload);
}

async function fetchQPointAccount() {
  const result = await qclawCommonFetch('data/4110/forward', {});
  assertQClawSuccess(result, 'data/4110/forward');
  return normalizeQPointAccount(extractRespData(result.payload));
}

async function fetchQPointFlows({ page = 1, pageSize = 20 } = {}) {
  const result = await qclawCommonFetch('data/4222/forward', {
    offset: (page - 1) * pageSize,
    limit: pageSize,
    page,
    page_size: pageSize,
  });
  assertQClawSuccess(result, 'data/4222/forward');
  return extractRespData(result.payload);
}

async function fetchUsageDetails({ startDate, endDate, page = 1, pageSize = 20 } = {}) {
  const result = await qclawCommonFetch('data/4172/forward', {
    start_date: startDate,
    end_date: endDate,
    offset: (page - 1) * pageSize,
    limit: pageSize,
    page,
    page_size: pageSize,
  });
  assertQClawSuccess(result, 'data/4172/forward');
  return extractRespData(result.payload);
}

function summarizeUsageDetails(details) {
  const records = Array.isArray(details?.records) ? details.records : [];
  const summary = records.reduce(
    (summary, record) => ({
      totalRecords: details?.total ?? records.length,
      promptTokens: summary.promptTokens + (Number(record.prompt_tokens) || 0),
      completionTokens: summary.completionTokens + (Number(record.completion_tokens) || 0),
      totalTokens: summary.totalTokens + (Number(record.total_tokens) || 0),
      cost: summary.cost + (Number(record.cost) || 0),
    }),
    {
      totalRecords: details?.total ?? records.length,
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
      cost: 0,
    }
  );
  return {
    ...summary,
    cost: Number(summary.cost.toFixed(12)),
  };
}

function normalizeQPointAccount(account) {
  const detail = account?.balance_detail || {};
  const dailyFree = Number(detail.daily_free) || 0;
  const activityQ = Number(detail.activity_q) || 0;
  return {
    balance: Number(account?.balance) || 0,
    activityPoints: Number((dailyFree + activityQ).toFixed(12)),
    subscriptionPoints: Number(detail.subscription_q) || 0,
    packagePoints: Number(detail.package_q) || 0,
    totalDailyFreeGranted: Number(account?.total_daily_free_granted) || 0,
    updatedAt: account?.updated_at || '',
    items: Array.isArray(detail.items) ? detail.items : [],
  };
}

function summarizeQPointFlows(details) {
  const flows = Array.isArray(details?.flows) ? details.flows : [];
  const summary = flows.reduce(
    (summary, flow) => {
      const amount = Number(flow.amount) || 0;
      if (flow.direction === 2) {
        summary.consumedInPage += amount;
      } else if (flow.direction === 1) {
        summary.gainedInPage += amount;
      }
      return summary;
    },
    {
      totalFlows: Number(details?.total) || flows.length,
      page: Number(details?.page) || 1,
      pageSize: Number(details?.page_size) || flows.length,
      flowCountInPage: flows.length,
      consumedInPage: 0,
      gainedInPage: 0,
    }
  );
  return {
    ...summary,
    consumedInPage: Number(summary.consumedInPage.toFixed(12)),
    gainedInPage: Number(summary.gainedInPage.toFixed(12)),
  };
}

export {
  decryptChromiumV10,
  decryptStoredValue,
  extractRespData,
  fetchDailyTokenUsage,
  fetchQClawModels,
  fetchQPointAccount,
  fetchQPointFlows,
  fetchUsageDetails,
  normalizeQPointAccount,
  normalizeModelRows,
  qclawCommonFetch,
  readQClawApiKey,
  readQClawAuthSession,
  summarizeQPointFlows,
  summarizeUsageDetails,
};
