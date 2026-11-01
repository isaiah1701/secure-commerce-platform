import http from 'k6/http';
import { check, sleep } from 'k6';
import { LAB_URL } from './scenario-config.mjs';
import { warmup } from './lab-runtime.js';

const base = (__ENV.BASE_URL || 'https://shop.platf0rm.site').replace(/\/$/, '');
const scenarioId = __ENV.SCENARIO_ID || `soc-api-read-burst-${Date.now()}`;
const requests = Number(__ENV.REQUESTS || 60);
const killSwitch = (__ENV.KILL_SWITCH || 'false').toLowerCase() === 'true';
if (base !== LAB_URL || !Number.isInteger(requests) || requests < 1 || requests > 60) throw new Error('Use 1–60 read-only requests on the owned lab');
if (!/^[A-Za-z0-9._-]{1,70}$/.test(scenarioId)) throw new Error('Use a bounded correlation identifier');
http.setResponseCallback(http.expectedStatuses(200));

export const options = {
  setupTimeout: '130s',
  scenarios: {
    bounded_api_read_burst: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: requests,
      maxDuration: '120s',
    },
  },
  thresholds: { checks: ['rate==1'], http_req_failed: ['rate==0'] },
};

export function setup() { warmup(base, scenarioId, killSwitch); }

export default function () {
  if (killSwitch) return;

  const response = http.get(`${base}/api/products?category=Electronics`, {
    headers: {
      'X-SOC-Scenario-ID': scenarioId,
      'X-Request-ID': `${scenarioId}-${__ITER}-${Date.now()}`,
    },
    timeout: '10s',
  });
  check(response, { 'read-only request completed': (result) => result.status === 200 });
  sleep(1);
}
