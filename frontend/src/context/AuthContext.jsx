import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import api, { refreshSession } from '../api/client';
import { resetBadges } from '../hooks/useBadges';
import { applyTheme } from '../hooks/useTheme';

const AuthContext = createContext();

function readStoredUser() {
  try {
    const saved = localStorage.getItem('user');
    if (!saved || saved === 'undefined' || saved === 'null') return null;
    return JSON.parse(saved);
  } catch (_) {
    return null;
  }
}

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(readStoredUser);
  // If we already have a cached user we can render immediately and validate in
  // the background — no blocking spinner on every page load.
  const [loading, setLoading] = useState(() => !!localStorage.getItem('token') && !readStoredUser());

  const clearSession = useCallback(() => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    localStorage.removeItem('token_refreshed_at');
    resetBadges();
    applyTheme('LIGHT');
    setUser(null);
  }, []);

  useEffect(() => {
    let alive = true;
    const token = localStorage.getItem('token');
    if (!token) {
      setLoading(false);
      return undefined;
    }

    (async () => {
      // Slide the 30-day session forward on every app open.
      await refreshSession(true);
      try {
        const res = await api.get('/auth/me');
        if (alive && res.data?.user) {
          const merged = { ...res.data.user, approver: res.data.approver || null };
          setUser(merged);
          localStorage.setItem('user', JSON.stringify(merged));
        }
      } catch (err) {
        // Only a real 401 ends the session; offline/5xx keeps the cached user.
        if (alive && err.response?.status === 401) clearSession();
      } finally {
        if (alive) setLoading(false);
      }
    })();

    // Profile changes made on the phone (photo, name…) show up here as soon
    // as the dashboard tab is looked at again.
    let lastMe = Date.now();
    const syncMe = async () => {
      if (!localStorage.getItem('token') || Date.now() - lastMe < 20_000) return;
      lastMe = Date.now();
      try {
        const res = await api.get('/auth/me');
        if (alive && res.data?.user) {
          const merged = { ...res.data.user, approver: res.data.approver || null };
          setUser(merged);
          localStorage.setItem('user', JSON.stringify(merged));
        }
      } catch (_) {
        /* offline: keep cached user */
      }
    };
    const onVisible = () => {
      if (document.visibilityState === 'visible') {
        refreshSession();
        syncMe();
      }
    };
    const onFocus = () => syncMe();
    window.addEventListener('focus', onFocus);
    const onExpired = () => setUser(null);
    document.addEventListener('visibilitychange', onVisible);
    window.addEventListener('session-expired', onExpired);
    return () => {
      alive = false;
      document.removeEventListener('visibilitychange', onVisible);
      window.removeEventListener('focus', onFocus);
      window.removeEventListener('session-expired', onExpired);
    };
  }, [clearSession]);

  const login = useCallback(async (email, password) => {
    const res = await api.post('/auth/login', { email, password });
    const { token, user: userData } = res.data;
    resetBadges();
    localStorage.setItem('token', token);
    localStorage.setItem('token_refreshed_at', String(Date.now()));
    localStorage.setItem('user', JSON.stringify(userData));
    setUser(userData);
    return userData;
  }, []);

  const logout = clearSession;

  const updateUserProfile = useCallback((updatedUser) => {
    setUser(updatedUser);
    localStorage.setItem('user', JSON.stringify(updatedUser));
  }, []);

  const value = useMemo(
    () => ({ user, login, logout, updateUserProfile, loading }),
    [user, login, logout, updateUserProfile, loading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => useContext(AuthContext);
