import type { Metadata } from 'next';
import type { FC, ReactNode } from 'react';
import type { IconType } from 'react-icons';
import {
  PiAppleLogo,
  PiAndroidLogo,
  PiDesktopTower,
  PiDownloadSimple,
  PiLinuxLogo,
  PiTerminal,
  PiWindowsLogo,
} from 'react-icons/pi';

export const metadata: Metadata = {
  title: 'Downloads',
  description:
    'Download OpenDeck — turn an old phone into a Stream Deck — for Windows, macOS, Linux, Android and iOS.',
  alternates: { canonical: '/downloads/' },
};

const GITHUB = 'https://github.com/hieudoanm/open.deck';
const RELEASES = `${GITHUB}/releases/latest`;
const RELEASE_PAGE = `${GITHUB}/releases`;

interface Asset {
  label: string;
  href: string;
}

interface Cell {
  name: string;
  icon: IconType;
  desc: string;
  assets: Asset[];
}

const DESKTOP: Cell[] = [
  {
    name: 'macOS',
    icon: PiAppleLogo,
    desc: 'OpenDeck companion app (QR pairing) and the open-deck-server binary.',
    assets: [{ label: 'macOS', href: RELEASES }],
  },
  {
    name: 'Windows',
    icon: PiWindowsLogo,
    desc: 'open-deck-server for Windows 10/11, x86_64.',
    assets: [{ label: 'Windows', href: RELEASES }],
  },
  {
    name: 'Linux',
    icon: PiLinuxLogo,
    desc: 'opendeck-linux companion app (GTK4/libadwaita) and server binary.',
    assets: [{ label: 'Linux', href: RELEASES }],
  },
];

const MOBILE: Cell[] = [
  {
    name: 'Android',
    icon: PiAndroidLogo,
    desc: 'OpenDeck app — sideload the APK or build from source with Gradle.',
    assets: [{ label: 'Android APK', href: RELEASES }],
  },
  {
    name: 'iOS',
    icon: PiAppleLogo,
    desc: 'OpenDeck app for iPhone and iPad — build with Xcode or TestFlight.',
    assets: [{ label: 'iOS', href: RELEASES }],
  },
];

function Section({
  icon: Icon,
  title,
  children,
}: {
  icon: IconType;
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="mb-12 last:mb-0">
      <h2 className="text-base-content mb-6 flex items-center gap-2 text-2xl leading-tight">
        <Icon className="text-primary h-6 w-6" />
        {title}
      </h2>
      {children}
    </div>
  );
}

function CardGrid({ cells, cols }: { cells: Cell[]; cols: string }) {
  const visible = cells.filter((c) => c.assets.length > 0);
  if (visible.length === 0) return null;
  return (
    <div className={`grid grid-cols-1 gap-6 sm:grid-cols-2 ${cols}`}>
      {visible.map((c) => (
        <div
          key={c.name}
          className="card border-base-300 bg-base-100 border p-6">
          <div className="bg-primary/10 text-primary mb-3.5 flex h-11 w-11 items-center justify-center rounded-lg">
            <c.icon className="h-6 w-6" />
          </div>
          <h3 className="text-base-content m-0 text-lg leading-tight">
            {c.name}
          </h3>
          <p className="text-base-content/60 mt-1 text-sm">{c.desc}</p>
          <div className="mt-4 flex flex-col gap-2">
            {c.assets.map((a) => (
              <a
                key={a.href + a.label}
                href={a.href}
                target="_blank"
                rel="noreferrer"
                className="btn btn-primary btn-sm gap-2">
                <PiDownloadSimple className="h-3.5 w-3.5" />
                {a.label}
              </a>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

const SOURCE_STEPS: { label: string; cmd: string }[] = [
  {
    label: 'Server (all desktop OSes)',
    cmd: 'git clone https://github.com/hieudoanm/open.deck && cd open.deck/server && cargo build --release',
  },
  {
    label: 'macOS companion app',
    cmd: 'cd open.deck/desktop/macos && swift run OpenDeckMac',
  },
  {
    label: 'Linux companion app',
    cmd: 'cd open.deck/desktop/linux && cargo build --release',
  },
  {
    label: 'Android app',
    cmd: 'cd open.deck/mobile/android && ./gradlew installDebug',
  },
  {
    label: 'iOS app',
    cmd: 'cd open.deck/mobile/ios && xcodegen generate && open OpenDeck.xcodeproj',
  },
];

const Downloads: FC = () => (
  <main>
    <section className="py-20">
      <div className="mx-auto w-full max-w-6xl px-5">
        <div className="mx-auto mb-12 max-w-2xl text-center">
          <h1 className="text-base-content m-0 text-4xl leading-tight tracking-normal text-balance">
            Download OpenDeck
          </h1>
          <p className="text-base-content/60 mt-3 text-lg">
            Turn an old phone into a stream deck for your PC — server on
            Windows, macOS or Linux; app on Android or iOS.
          </p>
          <p className="text-base-content/60 mt-3 text-lg">
            Prebuilt binaries are attached to the{' '}
            <a href={RELEASE_PAGE} className="text-primary">
              GitHub releases
            </a>
            .
          </p>
        </div>

        <Section icon={PiDesktopTower} title="Desktop">
          <CardGrid cells={DESKTOP} cols="lg:grid-cols-3" />
        </Section>

        <Section icon={PiAndroidLogo} title="Mobile">
          <CardGrid cells={MOBILE} cols="lg:grid-cols-2" />
        </Section>

        <div className="border-base-300 bg-base-200/50 rounded-2xl border p-6">
          <h2 className="text-base-content m-0 mb-2 flex items-center gap-2 text-lg leading-tight">
            <PiTerminal className="text-primary h-5 w-5" />
            Build from source
          </h2>
          <p className="text-base-content/60 mb-4 text-sm">
            Everything is open source — the server is a single Rust binary, the
            mobile apps are Kotlin/Swift, and the desktop companions are native.
          </p>
          <div className="space-y-3">
            {SOURCE_STEPS.map((s) => (
              <div key={s.label}>
                <div className="text-base-content/70 mb-1 text-xs font-semibold tracking-wide uppercase">
                  {s.label}
                </div>
                <pre className="bg-base-300 overflow-x-auto rounded-lg p-3 font-mono text-xs">
                  <code>{s.cmd}</code>
                </pre>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  </main>
);

export default Downloads;
