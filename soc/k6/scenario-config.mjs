import { createAuthLockoutScenario } from './auth-lockout-config.mjs';

export const LAB_URL = 'https://shop.platf0rm.site';
export const SCENARIOS = ['auth-lockout', 'auth-success-after-failures', 'registration-abuse', 'privilege-probe', 'admin-directory', 'suspicious-api', 'auth-rate-limit', 'multi-event'];

export function configuration(env) {
  const base = (env.BASE_URL || LAB_URL).replace(/\/$/, '');
  const scenario = env.SCENARIO || 'auth-lockout';
  const scenarioId = env.SCENARIO_ID || `soc-${scenario}-${Date.now()}`;
  const user = env.TEST_USER || '';
  const password = env.TEST_PASSWORD || '';
  if (base !== LAB_URL || !SCENARIOS.includes(scenario)) throw new Error('Use a supported scenario on the owned lab');
  if (!/^[A-Za-z0-9._-]{1,70}$/.test(scenarioId)) throw new Error('Use a bounded correlation identifier');
  if (scenario !== 'suspicious-api' && (!/^soc-[a-z0-9-]+@platf0rm\.site$/.test(user) || password.length < 10 || password.length > 120)) throw new Error('Use a dedicated synthetic account and its credential');
  if (scenario === 'admin-directory' && !user.startsWith('soc-admin-')) throw new Error('Use a dedicated synthetic administrator');
  const execution = scenario === 'auth-lockout' ? createAuthLockoutScenario(Number(env.ATTEMPTS || 8)) : { executor: 'per-vu-iterations', vus: 1, iterations: 1, maxDuration: '90s' };
  return { base, scenario, scenarioId, user, password, execution, disabled: String(env.KILL_SWITCH).toLowerCase() === 'true' };
}
