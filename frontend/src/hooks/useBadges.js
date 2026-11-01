import { useEffect, useSyncExternalStore } from 'react';
import { getMyBadges } from '../api/client';

// Tiny shared store so Layout, Achievements and Profile reuse one request.
let state = { data: null, loading: false, error: null, fetchedAt: 0 };
const listeners = new Set();
const emit = () => listeners.forEach((l) => l());
const set = (patch) => {
  state = { ...state, ...patch };
  emit();
};

let inFlight = null;
export function loadBadges(force = false) {
  if (!force && state.data && Date.now() - state.fetchedAt < 60_000) return Promise.resolve(state.data);
  if (inFlight) return inFlight;
  set({ loading: true, error: null });
  inFlight = getMyBadges()
    .then((data) => {
      set({ data, loading: false, fetchedAt: Date.now() });
      return data;
    })
    .catch((error) => {
      set({ loading: false, error });
      return state.data;
    })
    .finally(() => {
      inFlight = null;
    });
  return inFlight;
}

export function resetBadges() {
  state = { data: null, loading: false, error: null, fetchedAt: 0 };
  emit();
}

export function clearNewBadges() {
  if (!state.data) return;
  set({
    data: {
      ...state.data,
      newly_unlocked: [],
      badges: (state.data.badges || []).map((b) => ({ ...b, is_new: false })),
    },
  });
}

export function useBadges({ autoLoad = true } = {}) {
  const snap = useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => state
  );
  useEffect(() => {
    if (autoLoad) loadBadges();
  }, [autoLoad]);
  return snap;
}
