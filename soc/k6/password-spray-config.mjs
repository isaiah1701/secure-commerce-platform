export function sprayConfiguration(env) {
  const base = (env.BASE_URL || 'https://shop.platf0rm.site').replace(/\/$/, '');
  const users = (env.TEST_USERS || '').split(',').map((user) => user.trim().toLowerCase());
  const testPassword = env.TEST_PASSWORD || '';
  if (base !== 'https://shop.platf0rm.site') {
    throw new Error('Password spray is restricted to the owned lab');
  }
  if (users.length !== 5 || new Set(users).size !== 5 || users.some((user) => !/^soc-spray-[a-z0-9-]+@platf0rm\.site$/.test(user))) {
    throw new Error('Specify exactly five distinct soc-spray lab accounts');
  }
  if (testPassword.length < 10 || testPassword.length > 120) {
    throw new Error('Specify the common synthetic account password');
  }
  return { base, users, password: `${testPassword}-invalid` };
}
