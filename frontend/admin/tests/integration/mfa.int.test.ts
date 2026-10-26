// Runs against a local Supabase stack (supabase start), exercising the same
// auth calls the login page makes. Skipped unless the env vars are set:
//   WASLA_SUPABASE_URL, WASLA_SUPABASE_ANON_KEY, WASLA_SUPABASE_SERVICE_ROLE_KEY
// (see `supabase status -o env`). Never point it at a hosted project.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { authenticator } from 'otplib';

const url = process.env.WASLA_SUPABASE_URL;
const anonKey = process.env.WASLA_SUPABASE_ANON_KEY;
const serviceKey = process.env.WASLA_SUPABASE_SERVICE_ROLE_KEY;
const enabled = !!(url && anonKey && serviceKey && /localhost|127\.0\.0\.1/.test(url));

const noPersist = { auth: { persistSession: false, autoRefreshToken: false } };
const email = `mfa-${Date.now()}@test.local`;
const password = 'Test-password-123!';

describe.skipIf(!enabled)('staff TOTP flow against local Supabase', () => {
  let admin: SupabaseClient;
  let userId: string;
  let secret: string;
  let factorId: string;

  beforeAll(async () => {
    admin = createClient(url!, serviceKey!, noPersist);
    const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
    if (error) throw error;
    userId = data.user.id;
    const { error: roleError } = await admin.from('users').update({ user_type: 'admin' }).eq('id', userId);
    if (roleError) throw roleError;
  });

  afterAll(async () => {
    if (userId) await admin.auth.admin.deleteUser(userId);
  });

  const signIn = async () => {
    const client = createClient(url!, anonKey!, noPersist);
    const { error } = await client.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return client;
  };

  it('password alone gives aal1, and the role is readable via get_my_profile', async () => {
    const client = await signIn();
    const { data: aal } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
    expect(aal?.currentLevel).toBe('aal1');
    const { data: profile } = await client.rpc('get_my_profile').maybeSingle<{ user_type: string }>();
    expect(profile?.user_type).toBe('admin');
  });

  it('enrolling and verifying a TOTP factor raises the session to aal2', async () => {
    const client = await signIn();
    const { data: factors } = await client.auth.mfa.listFactors();
    expect(factors?.totp).toHaveLength(0);

    const { data: enrolled, error } = await client.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'Wasla Admin' });
    expect(error).toBeNull();
    expect(enrolled!.totp.qr_code.startsWith('data:image/svg+xml')).toBe(true);
    secret = enrolled!.totp.secret;
    factorId = enrolled!.id;

    const { error: verifyError } = await client.auth.mfa.challengeAndVerify({
      factorId,
      code: authenticator.generate(secret),
    });
    expect(verifyError).toBeNull();
    const { data: aal } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
    expect(aal?.currentLevel).toBe('aal2');
  });

  it('a new sign-in starts at aal1 and requires the code again; a wrong code is refused', async () => {
    const client = await signIn();
    const { data: aal } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
    expect(aal).toMatchObject({ currentLevel: 'aal1', nextLevel: 'aal2' });

    const { data: factors } = await client.auth.mfa.listFactors();
    expect(factors?.totp.find((f) => f.status === 'verified')?.id).toBe(factorId);

    const wrong = authenticator.generate(secret) === '000000' ? '111111' : '000000';
    const { error: wrongError } = await client.auth.mfa.challengeAndVerify({ factorId, code: wrong });
    expect(wrongError).not.toBeNull();

    const { error: okError } = await client.auth.mfa.challengeAndVerify({ factorId, code: authenticator.generate(secret) });
    expect(okError).toBeNull();
    const { data: after } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
    expect(after?.currentLevel).toBe('aal2');
  });
});
