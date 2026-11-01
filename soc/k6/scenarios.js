import http from 'k6/http';
import { check, sleep } from 'k6';
import { AUTH_LOCKOUT_DELAY_SECONDS } from './auth-lockout-config.mjs';
import { configuration } from './scenario-config.mjs';
import { warmup } from './lab-runtime.js';

const config = configuration(__ENV);
http.setResponseCallback(http.expectedStatuses(200, 201, 401, 403, 409, 429));

export const options = {
  setupTimeout: '130s',
  scenarios: { bounded_soc: config.execution },
  thresholds: { checks: ['rate==1'], http_req_failed: ['rate==0'] },
};

export function setup() { warmup(config.base, config.scenarioId, config.disabled); }

function headers(extra = {}) {
  return { ...extra, 'X-SOC-Scenario-ID': config.scenarioId, 'X-Request-ID': `${config.scenarioId}-${__VU}-${__ITER}-${Date.now()}` };
}

function login(password = config.password) {
  return http.post(`${config.base}/api/auth/login`, JSON.stringify({ email: config.user, password }), { headers: headers({ 'Content-Type': 'application/json' }), timeout: '10s' });
}

function validToken() {
  const response = login();
  if (!check(response, { 'synthetic login succeeds': (result) => result.status === 200 })) throw new Error('Synthetic login failed');
  sleep(1);
  return response.json('access_token');
}

export default function () {
  if (config.disabled) return;
  if (config.scenario === 'auth-lockout') {
    check(login(`${config.password}-invalid`), { 'invalid authentication rejected': (result) => result.status === 401 });
    sleep(AUTH_LOCKOUT_DELAY_SECONDS);
  } else if (config.scenario === 'auth-success-after-failures') {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      check(login(`${config.password}-invalid`), { 'invalid authentication rejected': (result) => result.status === 401 });
      sleep(1);
    }
    check(login(), { 'controlled synthetic login succeeds': (result) => result.status === 200 });
  } else if (config.scenario === 'registration-abuse') {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const response = http.post(`${config.base}/api/auth/register`, JSON.stringify({ email: config.user, password: config.password, first_name: 'SOC', last_name: 'Synthetic' }), { headers: headers({ 'Content-Type': 'application/json' }), timeout: '10s' });
      check(response, { 'duplicate registration rejected': (result) => result.status === 409 });
      sleep(1);
    }
  } else if (['privilege-probe', 'admin-directory'].includes(config.scenario)) {
    const token = validToken();
    const endpoint = config.scenario === 'admin-directory' ? '/api/admin/users' : '/api/admin/products';
    const expectedStatus = config.scenario === 'admin-directory' ? 200 : 403;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const response = http.get(`${config.base}${endpoint}`, { headers: headers({ Authorization: `Bearer ${token}` }), timeout: '10s' });
      check(response, { 'authorization outcome matches account role': (result) => result.status === expectedStatus });
      sleep(1);
    }
  } else if (config.scenario === 'suspicious-api') {
    check(http.get(`${config.base}/api/products?search=%2e%2e%2f`, { headers: headers(), timeout: '10s' }), { 'read-only request completed': (result) => result.status === 200 });
  } else if (config.scenario === 'auth-rate-limit') {
    for (let attempt = 0; attempt < 12; attempt += 1) {
      check(login(`${config.password}-invalid`), { 'bounded auth response': (result) => [401, 429].includes(result.status) });
      sleep(1);
    }
  } else if (config.scenario === 'multi-event') {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      check(login(`${config.password}-invalid`), { 'invalid authentication rejected': (result) => result.status === 401 });
      sleep(1);
    }
    const token = validToken();
    check(http.get(`${config.base}/api/admin/products`, { headers: headers({ Authorization: `Bearer ${token}` }), timeout: '10s' }), { 'customer denied administrator access': (result) => result.status === 403 });
  }
}
