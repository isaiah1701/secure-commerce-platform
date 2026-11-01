import assert from 'node:assert/strict';
import test from 'node:test';

import { AUTH_LOCKOUT_DELAY_SECONDS, createAuthLockoutScenario } from './auth-lockout-config.mjs';

test('auth-lockout uses one VU and a bounded six-to-eight-attempt run', () => {
  for (const attempts of [6, 7, 8]) {
    assert.deepEqual(createAuthLockoutScenario(attempts), {
      executor: 'shared-iterations',
      vus: 1,
      iterations: attempts,
      maxDuration: '25s',
    });
  }
  assert.equal(AUTH_LOCKOUT_DELAY_SECONDS, 2);
});

test('auth-lockout rejects unsafe attempt counts', () => {
  for (const attempts of [0, 5, 9, 1.5, Number.NaN]) {
    assert.throws(() => createAuthLockoutScenario(attempts));
  }
});
