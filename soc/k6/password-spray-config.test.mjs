import test from 'node:test';
import assert from 'node:assert/strict';
import { sprayConfiguration } from './password-spray-config.mjs';

const users = Array.from({ length: 5 }, (_, index) => `soc-spray-${index}@platf0rm.site`).join(',');
const env = { TEST_USERS: users, TEST_PASSWORD: 'SyntheticPassword123!' };

test('spray uses five lab accounts and a deliberately invalid password', () => {
  const configuration = sprayConfiguration(env);
  assert.equal(configuration.users.length, 5);
  assert.equal(configuration.base, 'https://shop.platf0rm.site');
  assert.equal(configuration.password, `${env.TEST_PASSWORD}-invalid`);
});

test('spray rejects other destinations, duplicate or non-synthetic accounts', () => {
  assert.throws(() => sprayConfiguration({ ...env, BASE_URL: 'https://example.com' }));
  assert.throws(() => sprayConfiguration({ ...env, TEST_USERS: Array(5).fill('soc-spray-1@platf0rm.site').join(',') }));
  assert.throws(() => sprayConfiguration({ ...env, TEST_USERS: users.replace('soc-spray-0', 'customer') }));
  assert.throws(() => sprayConfiguration({ ...env, TEST_PASSWORD: '' }));
});
