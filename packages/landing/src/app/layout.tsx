import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import type { FC, ReactNode } from 'react';
import Footer from '@/components/molecules/Footer';
import Navbar from '@/components/molecules/Navbar';
import './globals.css';

const THEME_INIT_SCRIPT = `(function(){try{var t=localStorage.getItem('opendeck-theme');if(!t){t=window.matchMedia('(prefers-color-scheme: dark)').matches?'opendeck-dark':'opendeck';}document.documentElement.setAttribute('data-theme',t);}catch(e){}})();`;

const inter = Inter({ subsets: ['latin'] });

const GITHUB = 'https://github.com/hieudoanm/open.deck';
const BASE = process.env.NODE_ENV === 'production' ? '/open.deck' : '';
const LOGO =
  process.env.NODE_ENV === 'production' ? '/open.deck/logo.svg' : '/logo.svg';
const NAV_LINKS = [
  { label: 'Features', href: '#features' },
  { label: 'How it works', href: '#how' },
  { label: 'Quickstart', href: '#quickstart' },
  { label: 'Docs', href: '/docs/' },
  { label: 'Downloads', href: '/downloads/' },
];

const SITE_URL = 'https://hieudoanm.github.io/open.deck';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'OpenDeck — turn an old phone into a Stream Deck',
    template: '%s — OpenDeck',
  },
  description:
    'OpenDeck streams your desktop to an old phone and turns touches into mouse and keyboard input — an open-source, self-hosted companion for Windows, macOS, Linux, Android and iOS.',
  manifest: `${BASE}/manifest.json`,
  icons: { icon: `${BASE}/icon.svg` },
  keywords: [
    'stream deck',
    'old phone remote desktop',
    'phone as stream deck',
    'self-hosted remote desktop',
    'open source',
    'Android',
    'iOS',
    'Windows',
    'macOS',
    'Linux',
  ],
  authors: [
    { name: 'hieudoan', url: 'https://github.com/hieudoanm/open.deck' },
  ],
  category: 'utilities',
  openGraph: {
    title: 'OpenDeck — turn an old phone into a Stream Deck',
    description:
      'Stream your desktop to an old phone and control it with touch — open source, local-first, no accounts.',
    images: ['/og.svg'],
  },
};

const JSON_LD = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'WebSite',
      name: 'OpenDeck',
      url: 'https://hieudoanm.github.io/open.deck/',
      description:
        'OpenDeck streams your desktop to an old phone and turns touches into mouse and keyboard input — an open-source, self-hosted companion for Windows, macOS, Linux, Android and iOS.',
    },
    {
      '@type': 'SoftwareApplication',
      name: 'OpenDeck',
      applicationCategory: 'UtilitiesApplication',
      description:
        'OpenDeck streams your desktop to an old phone and turns touches into mouse and keyboard input — an open-source, self-hosted companion for Windows, macOS, Linux, Android and iOS.',
      url: 'https://hieudoanm.github.io/open.deck/',
      codeRepository: 'https://github.com/hieudoanm/open.deck',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    },
  ],
};

const RootLayout: FC<{ children: ReactNode }> = ({ children }) => {
  return (
    <html
      lang="en"
      data-theme="opendeck"
      suppressHydrationWarning
      className={`h-full scroll-smooth antialiased motion-reduce:scroll-auto ${inter.className}`}>
      <body className="flex min-h-full flex-col">
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD) }}
        />
        <Navbar
          name="open.deck"
          logoSrc={LOGO}
          links={NAV_LINKS}
          githubUrl={GITHUB}
        />
        {children}
        <Footer
          name="open.deck"
          tagline="Old phone, new stream deck · MIT"
          githubUrl={GITHUB}
        />
      </body>
    </html>
  );
};

export default RootLayout;
