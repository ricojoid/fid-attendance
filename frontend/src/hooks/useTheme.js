import { useEffect } from 'react';
import { THEMES } from '../themes';

/** Apply a theme to <html> (data-theme / data-mode) and remember it. */
export function applyTheme(code) {
  const t = THEMES[code] ? code : 'LIGHT';
  const el = document.documentElement;
  el.dataset.theme = t;
  el.dataset.mode = THEMES[t].mode;
  el.style.colorScheme = THEMES[t].mode;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', THEMES[t].primary);
  try {
    localStorage.setItem('app_theme', t);
  } catch (_) {
    /* private mode */
  }
  return t;
}

/** Keeps <html> in sync with the signed-in user's theme. */
export function useApplyTheme(code) {
  useEffect(() => {
    applyTheme(code || 'LIGHT');
  }, [code]);
}
