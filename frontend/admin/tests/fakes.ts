// In-memory stand-ins for the Supabase clients used by lib/auth.ts and the
// server actions. Each test configures the session user, table rows and
// RPC results, then inspects the recorded calls.
import { vi } from 'vitest';

type Row = Record<string, unknown>;

export interface FakeState {
  sessionUser: { id: string; user_metadata?: Row } | null;
  aal: 'aal1' | 'aal2' | null;
  tables: Record<string, Row[]>;
  rpcResult: unknown;
  rpcCalls: { fn: string; args: Row }[];
  inserts: { table: string; row: Row }[];
  updates: { table: string; values: Row; filters: Row }[];
  signedUrls: { bucket: string; path: string; ttl: number }[];
  bans: { id: string; ban_duration: string }[];
}

export const state: FakeState = {
  sessionUser: null,
  aal: null,
  tables: {},
  rpcResult: { success: true },
  rpcCalls: [],
  inserts: [],
  updates: [],
  signedUrls: [],
  bans: [],
};

export function resetState() {
  state.sessionUser = null;
  state.aal = null;
  state.tables = {};
  state.rpcResult = { success: true };
  state.rpcCalls = [];
  state.inserts = [];
  state.updates = [];
  state.signedUrls = [];
  state.bans = [];
}

function query(table: string) {
  const filters: Row = {};
  let mode: 'select' | 'update' = 'select';
  let values: Row = {};
  const match = () =>
    (state.tables[table] ?? []).filter((r) => Object.entries(filters).every(([k, v]) => r[k] === v));

  const builder = {
    select: () => builder,
    eq: (col: string, val: unknown) => {
      filters[col] = val;
      return builder;
    },
    maybeSingle: async () => ({ data: match()[0] ?? null, error: null }),
    single: async () => ({ data: match()[0] ?? null, error: null }),
    update: (v: Row) => {
      mode = 'update';
      values = v;
      return builder;
    },
    insert: async (row: Row) => {
      state.inserts.push({ table, row });
      return { error: null };
    },
    upsert: async (row: Row) => {
      state.inserts.push({ table, row });
      return { error: null };
    },
    then: (resolve: (v: unknown) => void) => {
      if (mode === 'update') state.updates.push({ table, values, filters: { ...filters } });
      resolve({ data: null, error: null });
    },
  };
  return builder;
}

export const adminClient = {
  from: (table: string) => query(table),
  rpc: vi.fn(async (fn: string, args: Row) => {
    state.rpcCalls.push({ fn, args });
    return { data: state.rpcResult, error: null };
  }),
  storage: {
    from: (bucket: string) => ({
      createSignedUrl: async (path: string, ttl: number) => {
        state.signedUrls.push({ bucket, path, ttl });
        return { data: { signedUrl: `https://signed.test/${bucket}/${path}` }, error: null };
      },
    }),
  },
  auth: {
    admin: {
      updateUserById: async (id: string, attrs: { ban_duration: string }) => {
        state.bans.push({ id, ban_duration: attrs.ban_duration });
        return { data: { user: { id } }, error: null };
      },
    },
  },
};

export const serverClient = {
  auth: {
    getUser: async () => ({ data: { user: state.sessionUser } }),
    mfa: {
      getAuthenticatorAssuranceLevel: async () => ({
        data: state.sessionUser ? { currentLevel: state.aal, nextLevel: 'aal2' } : null,
        error: null,
      }),
    },
  },
};

// Staff tests sign in with a verified TOTP factor (aal2) unless told otherwise.
export function signInAs(id: string, profile: Row | null, userMetadata: Row = {}, aal: 'aal1' | 'aal2' = 'aal2') {
  state.sessionUser = { id, user_metadata: userMetadata };
  state.aal = aal;
  if (profile) {
    state.tables.users = [...(state.tables.users ?? []).filter((u) => u.id !== id), { id, deleted_at: null, ...profile }];
  }
}
