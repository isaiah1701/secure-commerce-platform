import assert from 'node:assert/strict';
import test from 'node:test';
import { configuration, SCENARIOS } from './scenario-config.mjs';

const env = { TEST_USER: 'soc-admin-test@platf0rm.site', TEST_PASSWORD: 'SyntheticOnly!2026', SCENARIO_ID: 'soc-test' };
test('every scenario is bounded to one VU and the owned lab', () => {
  for (const scenario of SCENARIOS) {
    const config = configuration({ ...env, SCENARIO: scenario });
    assert.equal(config.execution.vus, 1);
    assert.equal(config.base, 'https://shop.platf0rm.site');
  }
});
test('foreign targets and non-synthetic identities are rejected', () => {
  for (const overrides of [{ BASE_URL: 'https://example.com' }, { TEST_USER: 'admin@example.com' }, { TEST_PASSWORD: 'short' }, { SCENARIO: 'arbitrary' }, { SCENARIO_ID: '<script>' }]) assert.throws(() => configuration({ ...env, ...overrides }));
});
