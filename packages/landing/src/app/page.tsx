import type { Metadata } from 'next';
import Link from 'next/link';
import type { FC } from 'react';
import {
  PiCursorClick,
  PiDesktopTower,
  PiDeviceMobile,
  PiKeyboard,
  PiPlugsConnected,
  PiShieldCheck,
} from 'react-icons/pi';

import CTA from '@/components/molecules/CTA';
import Features, { type Feature } from '@/components/molecules/Features';
import Hero from '@/components/molecules/Hero';

export const metadata: Metadata = {
  alternates: { canonical: '/' },
};

const GITHUB = 'https://github.com/hieudoanm/open.deck';
const RELEASES = `${GITHUB}/releases`;

const FEATURES: Feature[] = [
  {
    title: 'The phone you already have',
    body: 'Any Android or iOS device works — including the old phone in your drawer. No new hardware to buy.',
    icon: PiDeviceMobile,
  },
  {
    title: 'A real stream deck',
    body: 'The screen shows your desktop live while touch acts as the mouse and the on-screen key bar sends real keystrokes.',
    icon: PiCursorClick,
  },
  {
    title: 'Full mouse & keyboard',
    body: 'Touch maps to absolute-pointer mouse control; the on-screen keyboard sends real key events, text and chords.',
    icon: PiKeyboard,
  },
  {
    title: 'Local-first, zero accounts',
    body: 'One WebSocket on your LAN. Pairing-token auth, no cloud, no telemetry, no sign-up — your screen never leaves home.',
    icon: PiShieldCheck,
  },
  {
    title: 'Runs everywhere',
    body: 'The Rust server targets Windows, macOS and Linux; companion apps for Android, iOS and macOS desktop.',
    icon: PiDesktopTower,
  },
  {
    title: 'An open protocol',
    body: 'Screen frames are JPEG over WebSocket; input is documented JSON. Anyone can write a client in an afternoon.',
    icon: PiPlugsConnected,
  },
];

const STEPS = [
  {
    title: 'Run the server',
    body: 'open-deck-server captures your primary monitor, JPEG-encodes frames and serves them over a single WebSocket.',
    code: 'open-deck-server --port 47821',
  },
  {
    title: 'Pair the phone',
    body: 'Install the OpenDeck app, point it at your PC’s address and enter the pairing token printed by the server.',
    code: 'ws://192.168.1.10:47821/ws?token=…',
  },
  {
    title: 'Deck it out',
    body: 'See your desktop live, tap to click and use the on-screen keys for ESC, TAB, arrows and more.',
    code: '{"type":"mouse_button","button":"left","state":"down"}',
  },
];

const PhoneMockup: FC = () => (
  <div className="mx-auto w-64">
    <div className="border-base-300 bg-base-100 rounded-[2.25rem] border-8 p-2 shadow-xl">
      <div className="bg-base-200 overflow-hidden rounded-[1.75rem]">
        {/* fake desktop stream */}
        <div className="relative h-44 bg-gradient-to-br from-blue-950 via-slate-900 to-slate-800 p-3">
          <div className="absolute top-1/2 left-1/2 h-1.5 w-10 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white/80" />
          <div className="mt-3 grid grid-cols-3 gap-1.5">
            {['OBS', 'Spotify', 'Mail'].map((app) => (
              <div
                key={app}
                className="rounded-md bg-white/10 px-1.5 py-1 text-center text-[9px] text-white/70 backdrop-blur">
                {app}
              </div>
            ))}
          </div>
          <div className="mt-2 h-16 rounded-md bg-white/10 p-1.5 backdrop-blur">
            <div className="h-1.5 w-2/3 rounded-full bg-white/20" />
            <div className="mt-1.5 h-1.5 w-1/2 rounded-full bg-white/15" />
            <div className="mt-1.5 h-1.5 w-3/5 rounded-full bg-white/15" />
          </div>
          <div className="bg-primary/80 absolute right-3 bottom-3 rounded-md px-2 py-1 text-[9px] font-semibold text-white">
            LIVE
          </div>
        </div>
        {/* stream deck buttons */}
        <div className="grid grid-cols-4 gap-1.5 p-3">
          {['Mic', 'Cam', 'Scene', 'Vol', 'Mute', 'Chat', 'Music', 'Focus'].map(
            (label, i) => (
              <div
                key={label}
                className={`flex h-11 items-center justify-center rounded-lg text-[10px] font-semibold ${
                  i === 2
                    ? 'bg-primary text-primary-content'
                    : 'bg-base-300 text-base-content/70'
                }`}>
                {label}
              </div>
            )
          )}
        </div>
      </div>
    </div>
  </div>
);

const Home: FC = () => (
  <main id="top">
    {/* hero */}
    <Hero
      title="That old phone in your drawer is a Stream Deck."
      description="OpenDeck streams your desktop to any phone and turns touches into mouse and keyboard input — a self-hosted, open-source companion for Windows, macOS, Linux, Android and iOS. No accounts, no cloud, no new hardware."
      primary={{
        label: 'Get started',
        href: '/docs/getting-started/quickstart/',
      }}
      secondary={{ label: 'Downloads', href: '/downloads/' }}
      stats={[
        { value: '5', label: 'platforms' },
        { value: '0', label: 'accounts or cloud' },
        { value: '1', label: 'WebSocket' },
      ]}>
      <PhoneMockup />
    </Hero>

    {/* how it works */}
    <section id="how" className="bg-base-200 py-20">
      <div className="mx-auto w-full max-w-6xl px-5">
        <div className="mx-auto mb-12 max-w-2xl text-center">
          <h2 className="text-base-content m-0 text-3xl leading-tight font-bold tracking-normal text-balance">
            Phone in, control out.
          </h2>
          <p className="text-base-content/60 mt-3 text-lg">
            One Rust server on your PC does the capture and input injection; the
            phone app is a thin client. Everything stays on your network.
          </p>
        </div>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
          {STEPS.map((step, i) => (
            <div
              key={step.title}
              className="card border-base-300 bg-base-100 border p-6">
              <div className="bg-accent/10 text-accent mb-3.5 flex h-11 w-11 items-center justify-center rounded-lg font-bold">
                {i + 1}
              </div>
              <h3 className="text-base-content m-0 mb-2 text-lg leading-tight">
                {step.title}
              </h3>
              <p className="text-base-content/60 text-sm">{step.body}</p>
              <code className="bg-base-200 text-base-content/70 mt-4 block overflow-x-auto rounded-lg px-3 py-2 font-mono text-xs">
                {step.code}
              </code>
            </div>
          ))}
        </div>
      </div>
    </section>

    {/* features */}
    <Features
      title="A stream deck that does more than stream."
      description="Live desktop view, absolute-pointer touch control and on-screen keys — with a configurable macro grid on the roadmap."
      features={FEATURES}
    />

    {/* quickstart */}
    <section id="quickstart" className="bg-base-200 py-20">
      <div className="mx-auto w-full max-w-6xl px-5">
        <div className="mx-auto mb-12 max-w-2xl text-center">
          <h2 className="text-base-content m-0 text-3xl leading-tight font-bold tracking-normal text-balance">
            Up and running in minutes.
          </h2>
          <p className="text-base-content/60 mt-3 text-lg">
            Build the server with Cargo, install the app on your phone, pair
            with the token. Full walkthrough in the{' '}
            <Link
              href="/docs/getting-started/quickstart/"
              className="text-primary">
              quickstart
            </Link>
            .
          </p>
        </div>
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <div className="mockup-code">
            <pre data-prefix="$">
              <code>cd server</code>
            </pre>
            <pre data-prefix="$">
              <code>cargo build --release</code>
            </pre>
            <pre data-prefix="$">
              <code>./target/release/open-deck-server</code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                === OpenDeck server is running ===
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                Pairing token : 9f2c…e41a
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                WebSocket URL : ws://&lt;this-pc&gt;:47821
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                Path : /ws?token=&lt;token&gt;
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                ===============================
              </code>
            </pre>
          </div>
          <div className="mockup-code">
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                1. Install OpenDeck on your phone (Android APK / iOS)
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                2. Enter your PC address — 192.168.1.10:47821
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-base-content/60">
                3. Paste the pairing token, tap Connect
              </code>
            </pre>
            <pre data-prefix=" ">
              <code className="text-accent">
                ● Live — desktop streamed, touch = mouse
              </code>
            </pre>
          </div>
        </div>
        <p className="text-base-content/60 mt-8 text-center text-sm">
          Prefer binaries? Grab the{' '}
          <a
            href={RELEASES}
            target="_blank"
            rel="noreferrer"
            className="text-primary">
            latest release
          </a>{' '}
          or read the{' '}
          <Link href="/docs/" className="text-primary">
            documentation
          </Link>
          .
        </p>
      </div>
    </section>

    <CTA
      title="Give that old phone a second life."
      description="Stream deck, remote desktop and macro pad in one — running entirely on your own network."
      primary={{ label: 'Downloads', href: '/downloads/' }}
      secondary={{ label: 'View Docs', href: '/docs/' }}
    />
  </main>
);

export default Home;
