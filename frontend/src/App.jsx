import React, { Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ErrorBoundary } from './components/ErrorBoundary';
import Layout from './components/Layout';
import Login from './pages/Login';

// Route-level code splitting: each page is downloaded only when visited,
// so the first load ships far less JavaScript.
const UserManagement = lazy(() => import('./pages/UserManagement'));
const Announcements = lazy(() => import('./pages/Announcements'));
const Profile = lazy(() => import('./pages/Profile'));
const AttendanceMonitoring = lazy(() => import('./pages/AttendanceMonitoring'));
const Achievements = lazy(() => import('./pages/Achievements'));
const Approvals = lazy(() => import('./pages/Approvals'));
const LocationMap = lazy(() => import('./pages/LocationMap'));
const Timeline = lazy(() => import('./pages/Timeline'));

function FullScreenLoader() {
  return (
    <div className="min-h-screen flex items-center justify-center aurora text-white">
      <span className="aurora-blob" />
      <div className="flex flex-col items-center gap-3">
        <div className="w-9 h-9 border-[3px] border-white/20 border-t-white rounded-full animate-spin" />
        <span className="text-sm text-white/60 font-semibold">Loading…</span>
      </div>
    </div>
  );
}

function PageLoader() {
  return (
    <div className="space-y-4 animate-fade-in">
      <div className="h-40 rounded-[32px] bg-slate-200/70 animate-pulse" />
      <div className="grid md:grid-cols-3 gap-4">
        {[0, 1, 2].map((i) => (
          <div key={i} className="h-28 rounded-3xl bg-slate-200/60 animate-pulse" />
        ))}
      </div>
    </div>
  );
}

const ProtectedRoute = ({ children, requireAdmin = false }) => {
  const { user, loading } = useAuth();

  if (loading) return <FullScreenLoader />;
  if (!user) return <Navigate to="/login" replace />;

  const roleUpper = (user.role || '').toUpperCase();
  const deptUpper = (user.department || '').toUpperCase();
  const canAdmin =
    roleUpper === 'SUPER_ADMIN' ||
    roleUpper === 'COUNTRY_HEAD' ||
    ['HUMAN RESOURCE', 'HUMAN RESOURCES', 'HR'].includes(deptUpper);

  if (requireAdmin && !canAdmin) return <Navigate to="/profile" replace />;

  return (
    <Layout>
      <Suspense fallback={<PageLoader />}>{children}</Suspense>
    </Layout>
  );
};

const page = (el, admin = false) => <ProtectedRoute requireAdmin={admin}>{el}</ProtectedRoute>;

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/attendance" element={page(<AttendanceMonitoring />)} />
            <Route path="/approvals" element={page(<Approvals />)} />
            <Route path="/map" element={page(<LocationMap />)} />
            <Route path="/timeline" element={page(<Timeline />)} />
            <Route path="/achievements" element={page(<Achievements />)} />
            <Route path="/users" element={page(<UserManagement />, true)} />
            <Route path="/announcements" element={page(<Announcements />)} />
            <Route path="/profile" element={page(<Profile />)} />
            <Route path="/" element={<Navigate to="/attendance" replace />} />
            <Route path="*" element={<Navigate to="/attendance" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ErrorBoundary>
  );
}
