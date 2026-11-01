import http from 'k6/http';
import { sleep } from 'k6';

export function warmup(base, scenarioId, disabled) {
  if (disabled) return;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const response = http.get(`${base}/ready`, {
      headers: { 'X-SOC-Scenario-ID': `${scenarioId}-warmup`, 'X-Request-ID': `${scenarioId}-ready-${attempt}` },
      timeout: '60s', responseCallback: http.expectedStatuses(200, 503),
    });
    sleep(1);
    if (response.status === 200) return;
  }
  throw new Error('Lab readiness failed; no attack requests were sent');
}
