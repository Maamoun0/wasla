import { describe, expect, it } from 'vitest';
import type { ErrorEvent } from '@sentry/nextjs';
import { scrubEvent, scrubText, sentryOptions } from '@/lib/observability/scrub';

describe('scrubText', () => {
  it('removes Egyptian phone numbers in any format', () => {
    for (const phone of ['01012345678', '+201012345678', '0101 234 5678', '+20-101-234-5678']) {
      expect(scrubText(`رقم ${phone} هنا`)).toBe('رقم [number] هنا');
    }
  });

  it('removes emails, JWTs, bearer tokens and token parameters', () => {
    expect(scrubText('user a.b+c@mail.example.com failed')).toBe('user [email] failed');
    expect(scrubText('jwt eyJhbGciOi.eyJzdWIiOi.sig-part_1')).toBe('jwt [token]');
    expect(scrubText('Authorization: Bearer abc.DEF-123')).toBe('Authorization: Bearer [token]');
    expect(scrubText('url?access_token=s3cr3t&x=1')).toBe('url?access_token=[filtered]&x=1');
    expect(scrubText('{"password": "hunter2"}')).toBe('{"password": "[filtered]"}');
  });

  it('keeps ordinary text and short numbers', () => {
    expect(scrubText('HTTP 404 at line 12')).toBe('HTTP 404 at line 12');
  });
});

describe('scrubEvent', () => {
  it('scrubs nested text, reduces the user to an id and drops request details', () => {
    const event = {
      type: undefined,
      message: 'login failed for 01012345678',
      exception: { values: [{ type: 'Error', value: 'no user x@y.com' }] },
      breadcrumbs: [{ message: 'GET ?token=abc', data: { phone: '+201012345678' } }],
      user: { id: 'u1', email: 'x@y.com', ip_address: '1.2.3.4' },
      request: { url: 'https://admin.test/x?phone=010', method: 'POST', headers: { cookie: 'sb=1' }, data: '{}' },
      extra: { body: { email: 'x@y.com' } },
    } as unknown as ErrorEvent;

    const out = scrubEvent(event);

    expect(out.message).toBe('login failed for [number]');
    expect(out.exception?.values?.[0].value).toBe('no user [email]');
    expect(out.breadcrumbs?.[0]).toEqual({ message: 'GET ?token=[filtered]', data: { phone: '[number]' } });
    expect(out.user).toEqual({ id: 'u1' });
    expect(out.request).toEqual({ url: 'https://admin.test/x', method: 'POST' });
    expect(out.extra).toEqual({ body: { email: '[email]' } });
  });
});

describe('sentryOptions', () => {
  it('is off without a DSN and never sends default PII', () => {
    expect(sentryOptions(undefined)).toMatchObject({ enabled: false, sendDefaultPii: false });
    expect(sentryOptions('https://k@o.ingest.sentry.io/1')).toMatchObject({ enabled: true, sendDefaultPii: false });
  });
});
