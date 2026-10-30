import http from 'k6/http';
import { check, sleep } from 'k6';

// Bounded lab traffic only. Use synthetic accounts on the owned commerce site.
const base = (__ENV.BASE_URL || 'https://shop.platf0rm.site').replace(/\/$/, '');
const scenarioId = __ENV.SCENARIO_ID || `soc-password-spray-${Date.now()}`;
const password = __ENV.TEST_PASSWORD || 'disabled';
const users = (__ENV.TEST_USERS || 'soc-spray-1@platf0rm.site,soc-spray-2@platf0rm.site,soc-spray-3@platf0rm.site,soc-spray-4@platf0rm.site,soc-spray-5@platf0rm.site').split(',');
const killSwitch = (__ENV.KILL_SWITCH || 'false').toLowerCase() === 'true';

export const options = {
  scenarios: {
    bounded_password_spray: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: '30s',
    },
  },
  thresholds: { checks: ['rate>0.9'] },
};

function headers() {
  return {
    'Content-Type': 'application/json',
    'X-SOC-Scenario-ID': scenarioId,
    'X-Request-ID': `${scenarioId}-${__ITER}-${Date.now()}`,
  };
}

export default function () {
  if (killSwitch) return;

  for (const email of users.slice(0, 5)) {
    const response = http.post(
      `${base}/api/auth/login`,
      JSON.stringify({ email: email.trim(), password }),
      { headers: headers(), timeout: '10s' },
    );
    check(response, { 'bounded authentication response': (r) => [401, 429].includes(r.status) });
  }
  sleep(1);
}
