import http from 'k6/http';
import { check, sleep } from 'k6';

const base = (__ENV.BASE_URL || 'https://shop.platf0rm.site').replace(/\/$/, '');
const scenario = __ENV.SCENARIO || 'auth-lockout';
const scenarioId = __ENV.SCENARIO_ID || `soc-${scenario}-${Date.now()}`;
const testUser = __ENV.TEST_USER || 'soc-test@example.com';
const testPassword = __ENV.TEST_PASSWORD || 'disabled';
const rate = Number(__ENV.RATE || 1);
const duration = __ENV.DURATION || '30s';
const killSwitch = (__ENV.KILL_SWITCH || 'false').toLowerCase() === 'true';

export const options = {
  scenarios: {
    bounded_soc: {
      executor: 'constant-arrival-rate',
      rate,
      timeUnit: '1s',
      duration,
      preAllocatedVUs: 1,
      maxVUs: 2,
    },
  },
  thresholds: { checks: ['rate>0.5'] },
};

function headers(extra = {}) {
  return {
    ...extra,
    'X-SOC-Scenario-ID': scenarioId,
    'X-Request-ID': `${scenarioId}-${__VU}-${__ITER}-${Date.now()}`,
  };
}

function login(password = testPassword, extra = {}) {
  return http.post(
    `${base}/api/auth/login`,
    JSON.stringify({ email: testUser, password }),
    { headers: headers({ 'Content-Type': 'application/json', ...extra }) },
  );
}

function validToken() {
  const response = login();
  check(response, { 'lab login succeeds': (r) => r.status === 200 });
  return response.json('access_token');
}

export default function () {
  if (killSwitch) return;

  if (scenario === 'auth-lockout') {
    const response = login(`${testPassword}-bad`);
    check(response, { 'failed login is observed': (r) => [401, 429].includes(r.status) });
  } else if (scenario === 'privilege-probe') {
    const token = validToken();
    const response = http.put(
      `${base}/api/admin/products/999999`,
      JSON.stringify({ name: 'SOC probe', description: 'controlled lab request', category: 'lab', price: 1, stock_quantity: 1 }),
      { headers: headers({ Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }) },
    );
    check(response, { 'admin boundary denies lab user': (r) => r.status === 403 });
  } else if (scenario === 'suspicious-api') {
    const response = http.get(`${base}/api/products?search=%27%20or%201%3D1`, { headers: headers() });
    check(response, { 'safe suspicious request responds': (r) => r.status < 500 });
  } else if (scenario === 'auth-rate-limit') {
    for (let attempt = 0; attempt < 12; attempt += 1) {
      const response = login(`${testPassword}-bad`);
      check(response, { 'bounded auth response': (r) => [401, 429].includes(r.status) });
    }
  } else if (scenario === 'multi-event') {
    login(`${testPassword}-bad`);
    login(`${testPassword}-bad`);
    const token = validToken();
    const response = http.get(`${base}/api/admin/products`, { headers: headers({ Authorization: `Bearer ${token}` }) });
    check(response, { 'correlated admin request is denied': (r) => r.status === 403 });
  } else {
    throw new Error(`Unknown SCENARIO=${scenario}`);
  }

  sleep(1);
}
