// In-memory stand-ins for the Supabase clients used by lib/auth.ts and the
// server actions. Each test configures the session user, table rows and
// RPC results, then inspects the recorded calls.
import { vi } from 'vitest';

type Row = Record<string, unknown>;

export interface FakeState {
  sessionUser: { id: string; user_metadata?: Row } | null;
  tables: Record<string, Row[]>;
  rpcResult: unknown;
  rpcCalls: { fn: string; args: Row }[];
  inserts: { table: string; row: Row }[];
  updates: { table: string; values: Row; filters: Row }[];
  signedUrls: { bucket: string; path: string; ttl: number }[];
  signOuts: string[];
}

export const state: FakeState = {
  sessionUser: null,
  tables: {},
  rpcResult: { success: true },
  rpcCalls: [],
  inserts: [],
  updates: [],
  signedUrls: [],
  signOuts: [],
};

export function resetState() {
  state.sessionUser = null;
  state.tables = {};
  state.rpcResult = { success: true };
  state.rpcCalls = [];
  state.inserts = [];
  state.updates = [];
  state.signedUrls = [];
  state.signOuts = [];
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
      signOut: async (id: string) => {
        state.signOuts.push(id);
        return { error: null };
      },
    },
  },
};

export const serverClient = {
  auth: {
    getUser: async () => ({ data: { user: state.sessionUser } }),
  },
};

export function signInAs(id: string, profile: Row | null, userMetadata: Row = {}) {
  state.sessionUser = { id, user_metadata: userMetadata };
  if (profile) {
    state.tables.users = [...(state.tables.users ?? []).filter((u) => u.id !== id), { id, deleted_at: null, ...profile }];
  }
}
