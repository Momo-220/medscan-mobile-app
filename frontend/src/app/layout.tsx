import type { Metadata, Viewport } from 'next';
import { Inter, Poppins } from 'next/font/google';
import './globals.css';

// Font configuration
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

// Metadata for SEO and PWA (automatically generates head tags)
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
    <html lang="fr" className={`${inter.variable} ${poppins.variable}`}>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
                navigator.serviceWorker.getRegistrations().then(function(registrations) {
                  var hasUnregistered = false;
                  for (var i = 0; i < registrations.length; i++) {
                    registrations[i].unregister();
                    hasUnregistered = true;
                  }
                  if (hasUnregistered) {
                    if ('caches' in window) {
                      caches.keys().then(function(names) {
                        for (var j = 0; j < names.length; j++) {
                          caches.delete(names[j]);
                        }
                      });
                    }
                    setTimeout(function() {
                      window.location.reload();
                    }, 200);
                  }
                });
              }
            `,
          }}
        />
      </head>
      <body className="antialiased bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 transition-colors">
        {children}
      </body>
    </html>
  );
}
