import './globals.css';
import type { Metadata } from 'next';

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
    <html lang="ar" dir="rtl">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@200..1000&display=swap" rel="stylesheet" />
      </head>
      <body>{children}</body>
    </html>
  );
}
