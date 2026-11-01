/** @type {import('next').NextConfig} */
module.exports = {
  // Loads instrumentation.ts (server-side Sentry, 🟡17); built in from Next 15.
  experimental: { instrumentationHook: true },
};
