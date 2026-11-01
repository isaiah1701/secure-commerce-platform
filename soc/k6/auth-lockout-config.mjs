export const AUTH_LOCKOUT_DELAY_SECONDS = 2;

export function createAuthLockoutScenario(attempts = 8) {
  if (!Number.isInteger(attempts) || attempts < 6 || attempts > 8) {
    throw new Error('Auth-lockout attempts must be an integer between 6 and 8');
  }

  return {
    executor: 'shared-iterations',
    vus: 1,
    iterations: attempts,
    maxDuration: '25s',
  };
}
