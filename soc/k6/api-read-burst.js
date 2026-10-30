import http from 'k6/http';
import { check } from 'k6';

// Read-only request burst for the owned lab. This does not create, update, or delete data.
const base = (__ENV.BASE_URL || 'https://shop.platf0rm.site').replace(/\/$/, '');
const scenarioId = __ENV.SCENARIO_ID || `soc-api-read-burst-${Date.now()}`;
const requests = Math.min(Number(__ENV.REQUESTS || 60), 60);
const killSwitch = (__ENV.KILL_SWITCH || 'false').toLowerCase() === 'true';

export const options = {
  scenarios: {
    bounded_api_read_burst: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: requests,
      maxDuration: '30s',
    },
  },
  thresholds: { checks: ['rate>0.95'] },
};

export default function () {
  if (killSwitch) return;

  const response = http.get(`${base}/api/products?category=Electronics`, {
    headers: {
      'X-SOC-Scenario-ID': scenarioId,
      'X-Request-ID': `${scenarioId}-${__ITER}-${Date.now()}`,
    },
  });
  check(response, { 'read-only request completed': (r) => r.status < 500 });
}
