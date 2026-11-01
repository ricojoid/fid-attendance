import { useEffect } from 'react';

/**
 * One EventSource per tab for live server pushes. Each event is re-emitted
 * as a window event (`live:<name>`) so any page can react to it.
 * EventSource reconnects automatically (server sends `retry: 3000`).
 */
export function useLiveEvents(enabled) {
  useEffect(() => {
    if (!enabled || typeof EventSource === 'undefined') return undefined;
    const token = localStorage.getItem('token');
    if (!token) return undefined;
    const base = import.meta.env.VITE_API_URL || '/api/v1';
    const es = new EventSource(`${base}/events?access_token=${encodeURIComponent(token)}`);
    const forward = (name) => (e) => {
      try {
        window.dispatchEvent(new CustomEvent(`live:${name}`, { detail: JSON.parse(e.data) }));
      } catch (_) {
        /* ignore malformed */
      }
    };
    const onAnn = forward('announcement');
    es.addEventListener('announcement', onAnn);
    return () => {
      es.removeEventListener('announcement', onAnn);
      es.close();
    };
  }, [enabled]);
}
