// wasla-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

// Load testing configuration as per Sprint 11 checklist
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp-up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp-up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests must be faster than 2s
    http_req_failed: ['rate<0.01'],    // Error rate must be less than 1%
  },
};

// Replace with actual Staging URL and Anon Key in real environment
const BASE_URL = 'https://wasla-staging.supabase.co'; 
const ANON_KEY = 'YOUR_STAGING_ANON_KEY'; 
const TEST_AD_ID = 'TEST_AD_UUID';

export default function () {
  const headers = {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${ANON_KEY}`,
  };

  // 1. Search & Browse (Most frequent operation)
  const searchRes = http.get(
    `${BASE_URL}/rest/v1/ads?status=eq.active&select=*&limit=20`,
    { headers: headers }
  );
  check(searchRes, {
    'search status 200': (r) => r.status === 200,
    'search time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);

  // 2. Ad Detail View
  const detailRes = http.get(
    `${BASE_URL}/rest/v1/ads?id=eq.${TEST_AD_ID}&select=*,profiles(*)&limit=1`,
    { headers: headers }
  );
  check(detailRes, {
    'detail status 200': (r) => r.status === 200,
  });
  sleep(1);
}
