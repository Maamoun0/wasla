'use client';

import * as Sentry from '@sentry/nextjs';
import { useEffect } from 'react';

export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);
  return (
    <html lang="ar" dir="rtl">
      <body style={{ fontFamily: 'sans-serif', padding: 24, textAlign: 'center' }}>
        <p>حصل خطأ غير متوقع.</p>
        <button onClick={reset}>حاول تاني</button>
      </body>
    </html>
  );
}
