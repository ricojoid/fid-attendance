import axios from 'axios';

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
    }
    return Promise.reject(error);
  }
);

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

export default api;
