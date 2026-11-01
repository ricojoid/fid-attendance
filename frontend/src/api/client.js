import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api/v1',
  headers: { 'Content-Type': 'application/json' },
  timeout: 20000,
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  },
  (error) => Promise.reject(error)
);

// Only an explicit 401 ends the session. Network errors / server restarts must
// never log the user out.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    const url = error.config?.url || '';
    if (error.response?.status === 401 && !url.includes('/auth/login')) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      localStorage.removeItem('token_refreshed_at');
      window.dispatchEvent(new Event('session-expired'));
    }
    return Promise.reject(error);
  }
);

// ---------------------------------------------------------------------------
// Sliding 30-day session: refresh the token whenever the app is opened or the
// tab becomes visible again (throttled). Logout only happens after 30 days
// without opening the app, when the server finally answers 401.
// ---------------------------------------------------------------------------
const REFRESH_EVERY_MS = 6 * 60 * 60 * 1000;
let refreshInFlight = null;

export function refreshSession(force = false) {
  const token = localStorage.getItem('token');
  if (!token) return Promise.resolve(false);
  const last = Number(localStorage.getItem('token_refreshed_at') || 0);
  if (!force && Date.now() - last < REFRESH_EVERY_MS) return Promise.resolve(true);
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = api
    .post('/auth/refresh')
    .then((res) => {
      if (res.data?.token) {
        localStorage.setItem('token', res.data.token);
        localStorage.setItem('token_refreshed_at', String(Date.now()));
        if (res.data.user) localStorage.setItem('user', JSON.stringify(res.data.user));
      }
      return true;
    })
    .catch((err) => err.response?.status !== 401) // offline → still signed in
    .finally(() => {
      refreshInFlight = null;
    });
  return refreshInFlight;
}

export const getAnnouncements = async (all = false) => {
  const res = await api.get(`/announcements${all ? '?all=true' : ''}`);
  return res.data;
};

export const createAnnouncement = async (payload) => {
  const res = await api.post('/admin/announcements', payload);
  return res.data;
};

export const updateAnnouncement = async (id, payload) => {
  const res = await api.put(`/admin/announcements/${id}`, payload);
  return res.data;
};

export const deleteAnnouncement = async (id) => {
  const res = await api.delete(`/admin/announcements/${id}`);
  return res.data;
};

// Badges
export const getMyBadges = async () => (await api.get('/badges/me')).data;
export const getUserBadges = async (id) => (await api.get(`/badges/user/${id}`)).data;
export const markBadgesSeen = async (codes) => (await api.post('/badges/seen', { codes })).data;

// Approvals
export const getPendingApprovals = async () => (await api.get('/approval/pending')).data?.data || [];
export const processApproval = async (type, id, status) =>
  (await api.post('/approval/process', { type, id, status })).data;
export const getMyApprover = async () => (await api.get('/approval/my-approver')).data?.approver || null;

export default api;
