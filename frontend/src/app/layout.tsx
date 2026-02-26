import type { Metadata, Viewport } from 'next';
import { Inter, Poppins } from 'next/font/google';
import './globals.css';
import { Providers } from '@/components/providers';

// Font configuration - double typographie
const inter = Inter({
  subsets: ['latin'],
  variable: '--font-lufga',
  display: 'swap',
});

const poppins = Poppins({
  subsets: ['latin'],
  weight: ['600', '700', '800'],
  variable: '--font-poppins',
  display: 'swap',
});

// Metadata for SEO and PWA
export const metadata: Metadata = {
  title: 'MediScan - Your Pharmaceutical Companion',
  description: 'A calm, intelligent, and trustworthy companion for medication management. Scan, learn, and stay safe with pharmaceutical guidance.',
  keywords: ['medication', 'pharmacy', 'health', 'safety', 'drug interactions'],
  authors: [{ name: 'MediScan Team' }],
  manifest: '/manifest.json',
  icons: {
    icon: '/logo.png',
    apple: '/logo.png',
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'MediScan',
  },
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: 'website',
    siteName: 'MediScan',
    title: 'MediScan - Your Pharmaceutical Companion',
    description: 'Intelligent medication management',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'MediScan',
    description: 'Your pharmaceutical companion',
  },
};

export const viewport: Viewport = {
  themeColor: '#4A90E2',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  userScalable: true,
  viewportFit: 'cover',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr" className={`${inter.variable} ${poppins.variable}`} suppressHydrationWarning>
      <head>
        <link rel="icon" type="image/png" href="/logo.png" />
        <link rel="apple-touch-icon" href="/logo.png" />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link rel="preconnect" href="https://apis.google.com" />
        {process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN && (
          <link rel="preconnect" href={`https://${process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN}`} />
        )}
        <link rel="dns-prefetch" href="https://storage.googleapis.com" />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="Permissions-Policy" content="camera=(self), microphone=()" />
      </head>
      <body className="antialiased bg-background dark:bg-gray-900 text-text-primary dark:text-gray-100 transition-colors">
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}


