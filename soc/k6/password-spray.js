import http from 'k6/http';
import { check, sleep } from 'k6';
import { sprayConfiguration } from './password-spray-config.mjs';
import { warmup } from './lab-runtime.js';

// Bounded lab traffic only. Use synthetic accounts on the owned commerce site.
const scenarioId = __ENV.SCENARIO_ID || `soc-password-spray-${Date.now()}`;
const killSwitch = (__ENV.KILL_SWITCH || 'false').toLowerCase() === 'true';
const { base, users, password } = sprayConfiguration(__ENV);

export const options = {
  setupTimeout: '130s',
  scenarios: {
    bounded_password_spray: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: 1,
      maxDuration: '30s',
    },
  },
  thresholds: { checks: ['rate==1'], http_req_failed: ['rate==0'] },
};

http.setResponseCallback(http.expectedStatuses(401));

export function setup() {
  warmup(base, scenarioId, killSwitch);
}

function headers() {
  return {
    'Content-Type': 'application/json',
    'X-SOC-Scenario-ID': scenarioId,
    'X-Request-ID': `${scenarioId}-${__ITER}-${Date.now()}`,
  };
}

export default function () {
  if (killSwitch) return;

  for (const email of users) {
    const response = http.post(
      `${base}/api/auth/login`,
      JSON.stringify({ email: email.trim(), password }),
      { headers: headers(), timeout: '10s' },
    );
    check(response, { 'failed authentication observed': (response) => response.status === 401 });
    sleep(2);
  }
}
