import { useCallback, useEffect, useRef, useState } from 'react';

export type WakeState = 'on' | 'off' | 'unsupported' | null;

// Keeps the screen awake while mounted: native Screen Wake Lock where
// available (secure contexts), otherwise a hidden muted looping video —
// iOS keeps the display on during video playback.
export function useWakeLock(): WakeState {
  const [state, setState] = useState<WakeState>(null);
  const sentinelRef = useRef<WakeLockSentinel | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  const ensureVideo = useCallback(() => {
    if (!videoRef.current) {
      const v = document.createElement('video');
      v.src = 'wake.mp4';
      v.loop = true;
      v.muted = true;
      v.playsInline = true;
      v.setAttribute('playsinline', '');
      v.preload = 'auto';
      v.style.cssText =
        'position:fixed;width:1px;height:1px;opacity:0;pointer-events:none;';
      document.body.appendChild(v);
      videoRef.current = v;
    }
    return videoRef.current;
  }, []);

  const acquire = useCallback(async () => {
    if ('wakeLock' in navigator) {
      try {
        const s = await navigator.wakeLock.request('screen');
        sentinelRef.current = s;
        s.addEventListener('release', () => setState('off'));
        setState('on');
        return;
      } catch {
        /* fall through to video fallback */
      }
    }
    try {
      await ensureVideo().play();
      setState('on');
    } catch {
      // iOS requires a user gesture before media can play.
      setState('off');
      const retry = () => {
        ensureVideo()
          .play()
          .then(() => setState('on'))
          .catch(() => {});
      };
      document.body.addEventListener('pointerdown', retry, { once: true });
    }
  }, [ensureVideo]);

  useEffect(() => {
    acquire();
    const onVis = () => {
      if (document.visibilityState === 'visible') acquire();
    };
    document.addEventListener('visibilitychange', onVis);
    return () => {
      document.removeEventListener('visibilitychange', onVis);
      sentinelRef.current?.release().catch(() => {});
      sentinelRef.current = null;
      videoRef.current?.pause();
    };
  }, [acquire]);

  return state;
}
