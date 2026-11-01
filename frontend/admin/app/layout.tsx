import './globals.css';
import type { Metadata } from 'next';
import { Cairo } from 'next/font/google';
import ErrorReportingInit from '@/components/ErrorReportingInit';

// Self-hosted at build time; exposed as --font-cairo for Tailwind and globals.css.
const cairo = Cairo({ subsets: ['arabic', 'latin'], display: 'swap', variable: '--font-cairo' });

export const metadata: Metadata = {
  title: 'لوحة تحكم وصلة | Wasla Admin',
  description: 'لوحة التحكم والإدارة لمنصة وصلة',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl" className={cairo.variable}>
      <body>
        <ErrorReportingInit />
        {children}
      </body>
    </html>
  );
}
