import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { ErrorBoundary } from './components/ErrorBoundary';
import Layout from './components/Layout';
import Login from './pages/Login';
import UserManagement from './pages/UserManagement';
import Announcements from './pages/Announcements';
import Profile from './pages/Profile';
import AttendanceMonitoring from './pages/AttendanceMonitoring';

const ProtectedRoute = ({ children, requireAdmin = false }) => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-slate-950 text-white font-medium">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-4 border-red-600 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm text-slate-400">Loading system...</span>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  const roleUpper = (user.role || '').toUpperCase();
  const deptUpper = (user.department || '').toUpperCase();
  const canAdmin =
    roleUpper === 'SUPER_ADMIN' ||
    roleUpper === 'COUNTRY_HEAD' ||
    deptUpper === 'HUMAN RESOURCE' ||
    deptUpper === 'HUMAN RESOURCES' ||
    deptUpper === 'HR';

  if (requireAdmin && !canAdmin) {
    return <Navigate to="/profile" replace />;
  }

  return <Layout>{children}</Layout>;
};

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            
            <Route
              path="/attendance"
              element={
                <ProtectedRoute>
                  <AttendanceMonitoring />
                </ProtectedRoute>
              }
            />

            <Route
              path="/users"
              element={
                <ProtectedRoute requireAdmin={true}>
                  <UserManagement />
                </ProtectedRoute>
              }
            />

            <Route
              path="/announcements"
              element={
                <ProtectedRoute>
                  <Announcements />
                </ProtectedRoute>
              }
            />

            <Route
              path="/profile"
              element={
                <ProtectedRoute>
                  <Profile />
                </ProtectedRoute>
              }
            />

            <Route path="/" element={<Navigate to="/attendance" replace />} />
            <Route path="*" element={<Navigate to="/attendance" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ErrorBoundary>
  );
}
