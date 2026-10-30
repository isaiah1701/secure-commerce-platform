import http from 'k6/http';
import { check, sleep } from 'k6';

const base = __ENV.BASE_URL || 'https://shop.platf0rm.site';
const scenarioId = __ENV.SCENARIO_ID || `soc-${Date.now()}`;
const testUser = __ENV.TEST_USER || 'soc-test@example.invalid';
const testPassword = __ENV.TEST_PASSWORD || 'disabled';
const killSwitch = (__ENV.KILL_SWITCH || 'false').toLowerCase() === 'true';

export const options = {
  scenarios: {
    bounded_soc: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 1),
      timeUnit: '1s',
      duration: __ENV.DURATION || '60s',
      preAllocatedVUs: 1,
      maxVUs: 2,
    },
  },
  thresholds: { checks: ['rate>0.5'] },
};

export default function () {
  if (killSwitch) return;
  const headers = { 'X-SOC-Scenario-ID': scenarioId };
  const failed = http.post(`${base}/api/auth/login`, JSON.stringify({ email: testUser, password: `${testPassword}-bad` }), { headers: { ...headers, 'Content-Type': 'application/json' } });
  check(failed, { 'failed login is observed': (r) => [400, 401, 403, 404, 422, 429].includes(r.status) });
  const normal = http.get(`${base}/api/products`, { headers });
  check(normal, { 'products endpoint responds': (r) => r.status < 500 });
  sleep(1);
}
