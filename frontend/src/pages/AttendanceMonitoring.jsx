import React, { useState, useEffect, useMemo } from 'react';
import api from '../api/client';
import {
  Calendar as CalendarIcon,
  Search,
  Users,
  CheckCircle2,
  Clock,
  CalendarX2,
  UserX,
  ChevronLeft,
  ChevronRight,
  RotateCcw,
  Download,
  Filter,
  MapPin,
  Building2,
  AlertCircle,
  X,
  CalendarDays,
  ExternalLink,
  Hourglass,
  Briefcase,
  ShieldCheck,
  ShieldAlert
} from 'lucide-react';

export default function AttendanceMonitoring() {
  // Helper for today in YYYY-MM-DD
  const getTodayStr = () => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  // Helper for current month in YYYY-MM
  const getCurrentMonthStr = () => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
  };

  const [selectedDate, setSelectedDate] = useState(getTodayStr());
  const [attendanceData, setAttendanceData] = useState([]);
  const [canViewAll, setCanViewAll] = useState(true);
  const [summary, setSummary] = useState({
    total: 0,
    present: 0,
    late: 0,
    leave: 0,
    absent: 0,
  });
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [departmentFilter, setDepartmentFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [error, setError] = useState('');

  // Modal State for Individual User Monthly History
  const [selectedUserModal, setSelectedUserModal] = useState(null);
  const [modalMonth, setModalMonth] = useState(getCurrentMonthStr());
  const [monthlyData, setMonthlyData] = useState(null);
  const [monthlyLoading, setMonthlyLoading] = useState(false);
  const [monthlyError, setMonthlyError] = useState('');

  // Fetch all attendance for selected date
  const fetchAttendance = async (date) => {
    try {
      setLoading(true);
      setError('');
      const res = await api.get(`/attendance/all?date=${date}`);
      const payload = res.data;
      setAttendanceData(payload.data || []);
      setCanViewAll(payload.can_view_all !== false);
      setSummary(
        payload.summary || {
          total: 0,
          present: 0,
          late: 0,
          leave: 0,
          absent: 0,
        }
      );
    } catch (err) {
      console.error('Failed to fetch attendance:', err);
      setError(err.response?.data?.error || 'Failed to load attendance records');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAttendance(selectedDate);
  }, [selectedDate]);

  // Fetch individual user monthly logs
  const fetchMonthlyLogs = async (userId, month) => {
    try {
      setMonthlyLoading(true);
      setMonthlyError('');
      const res = await api.get(`/attendance/user/${userId}?month=${month}`);
      setMonthlyData(res.data);
    } catch (err) {
      console.error('Failed to fetch monthly attendance:', err);
      setMonthlyError(err.response?.data?.error || 'Failed to load monthly attendance history');
    } finally {
      setMonthlyLoading(false);
    }
  };

  // Open modal for a specific user
  const handleOpenUserModal = (userItem) => {
    setSelectedUserModal(userItem);
    const initialMonth = getCurrentMonthStr();
    setModalMonth(initialMonth);
    fetchMonthlyLogs(userItem.user_id, initialMonth);
  };

  // Close modal
  const handleCloseUserModal = () => {
    setSelectedUserModal(null);
    setMonthlyData(null);
    setMonthlyError('');
  };

  // Navigate Modal Months
  const shiftModalMonth = (offset) => {
    if (!selectedUserModal) return;
    const parts = modalMonth.split('-');
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    const date = new Date(year, month - 1 + offset, 1);
    const newYear = date.getFullYear();
    const newMonth = String(date.getMonth() + 1).padStart(2, '0');
    const newMonthStr = `${newYear}-${newMonth}`;
    setModalMonth(newMonthStr);
    fetchMonthlyLogs(selectedUserModal.user_id || selectedUserModal.id, newMonthStr);
  };

  const handleMonthInputChange = (e) => {
    const val = e.target.value;
    if (val && selectedUserModal) {
      setModalMonth(val);
      fetchMonthlyLogs(selectedUserModal.user_id || selectedUserModal.id, val);
    }
  };

  // Date Navigation Helpers for Daily View
  const shiftDate = (days) => {
    const current = new Date(selectedDate);
    current.setDate(current.getDate() + days);
    const year = current.getFullYear();
    const month = String(current.getMonth() + 1).padStart(2, '0');
    const day = String(current.getDate()).padStart(2, '0');
    setSelectedDate(`${year}-${month}-${day}`);
  };

  const handleSetToday = () => {
    setSelectedDate(getTodayStr());
  };

  const handleSetYesterday = () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const year = yesterday.getFullYear();
    const month = String(yesterday.getMonth() + 1).padStart(2, '0');
    const day = String(yesterday.getDate()).padStart(2, '0');
    setSelectedDate(`${year}-${month}-${day}`);
  };

  // Format Time Helper
  const formatTime = (timeStr) => {
    if (!timeStr) return '--:--';
    try {
      if (timeStr.length === 5 && timeStr.includes(':')) return timeStr;
      if (timeStr.includes(' ') && !timeStr.includes('T')) {
        const parts = timeStr.split(' ');
        if (parts.length >= 2 && parts[1].includes(':')) {
          return parts[1].substring(0, 5);
        }
      }
      const dt = new Date(timeStr);
      if (isNaN(dt.getTime())) return '--:--';
      const hours = String(dt.getHours()).padStart(2, '0');
      const minutes = String(dt.getMinutes()).padStart(2, '0');
      return `${hours}:${minutes}`;
    } catch {
      return '--:--';
    }
  };

  // Unique Departments for filter
  const departments = useMemo(() => {
    const set = new Set();
    attendanceData.forEach((item) => {
      if (item.department) set.add(item.department);
    });
    return Array.from(set).sort();
  }, [attendanceData]);

  // Filtered list
  const filteredData = useMemo(() => {
    return attendanceData.filter((item) => {
      const matchSearch =
        search === '' ||
        (item.name && item.name.toLowerCase().includes(search.toLowerCase())) ||
        (item.nip && item.nip.toLowerCase().includes(search.toLowerCase())) ||
        (item.email && item.email.toLowerCase().includes(search.toLowerCase()));

      const matchDept =
        departmentFilter === 'ALL' || item.department === departmentFilter;

      const matchStatus =
        statusFilter === 'ALL' || item.status === statusFilter;

      return matchSearch && matchDept && matchStatus;
    });
  }, [attendanceData, search, departmentFilter, statusFilter]);

  // Export Daily to CSV
  const handleExportDailyCSV = () => {
    if (filteredData.length === 0) return;
    const headers = ['NIP', 'Name', 'Department', 'Email', 'Date', 'Status', 'Check In', 'Check Out', 'Location'];
    const rows = filteredData.map((item) => [
      `"${item.nip || ''}"`,
      `"${item.name || ''}"`,
      `"${item.department || ''}"`,
      `"${item.email || ''}"`,
      `"${item.date || selectedDate}"`,
      `"${item.status || ''}"`,
      `"${formatTime(item.check_in_time)}"`,
      `"${formatTime(item.check_out_time)}"`,
      `"${(item.location || '').replace(/"/g, '""')}"`,
    ]);

    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `Attendance_Daily_${selectedDate}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Export Monthly to CSV
  const handleExportMonthlyCSV = () => {
    if (!monthlyData || !monthlyData.days || monthlyData.days.length === 0) return;
    const userName = monthlyData.user?.name || 'User';
    const userNip = monthlyData.user?.nip || '';
    const headers = ['Date', 'Day', 'Status', 'Check In', 'Check Out', 'Duration', 'Notes'];
    const rows = monthlyData.days.map((d) => [
      `"${d.date}"`,
      `"${d.day_name}"`,
      `"${d.status}"`,
      `"${formatTime(d.check_in_time)}"`,
      `"${formatTime(d.check_out_time)}"`,
      `"${d.duration || '-'}"`,
      `"${(d.location || d.notes || '').replace(/"/g, '""')}"`,
    ]);

    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `Attendance_${userName.replace(/\s+/g, '_')}_${modalMonth}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 'PRESENT':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
            <CheckCircle2 className="w-3.5 h-3.5" />
            Present
          </span>
        );
      case 'LATE':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200">
            <Clock className="w-3.5 h-3.5" />
            Late
          </span>
        );
      case 'LEAVE':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-sky-50 text-sky-700 border border-sky-200">
            <CalendarX2 className="w-3.5 h-3.5" />
            On Leave
          </span>
        );
      case 'WEEKEND':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-500 border border-slate-200">
            Weekend Off
          </span>
        );
      case 'FUTURE':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-50 text-slate-400 border border-slate-200/60">
            Upcoming
          </span>
        );
      case 'ABSENT':
      default:
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-rose-50 text-rose-700 border border-rose-200">
            <UserX className="w-3.5 h-3.5" />
            Not Checked In
          </span>
        );
    }
  };

  // Format Month Title Helper (e.g. "September 2026")
  const formatMonthTitle = (monthStr) => {
    try {
      const parts = monthStr.split('-');
      const d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, 1);
      return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    } catch {
      return monthStr;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header with Title, Role Access Badge & Date Selector */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <h1 className="text-xl font-extrabold text-slate-900 tracking-tight">
              Attendance Monitoring
            </h1>
            {canViewAll ? (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                <ShieldCheck className="w-3.5 h-3.5" />
                Admin & HR Access (All Users)
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200">
                <ShieldAlert className="w-3.5 h-3.5" />
                Personal Attendance View
              </span>
            )}
          </div>
          <p className="text-sm text-slate-500 mt-1">
            {canViewAll
              ? 'Real-time presence, daily check-in/out timestamps, and click employee to inspect monthly history.'
              : 'Viewing your personal attendance logs. Manager/HR role is required to monitor other employees.'}
          </p>
        </div>

        {/* Date Filter Controls */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Quick Date Selectors */}
          <div className="flex items-center bg-slate-100 p-1 rounded-xl border border-slate-200">
            <button
              onClick={() => shiftDate(-1)}
              className="p-1.5 hover:bg-white text-slate-600 hover:text-slate-900 rounded-lg transition-colors"
              title="Previous Day"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button
              onClick={handleSetToday}
              className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
                selectedDate === getTodayStr()
                  ? 'bg-white text-red-600 shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Today
            </button>
            <button
              onClick={handleSetYesterday}
              className="px-3 py-1 text-xs font-semibold rounded-lg text-slate-600 hover:text-slate-900 transition-colors"
            >
              Yesterday
            </button>
            <button
              onClick={() => shiftDate(1)}
              className="p-1.5 hover:bg-white text-slate-600 hover:text-slate-900 rounded-lg transition-colors"
              title="Next Day"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>

          {/* Native HTML Date Input with Calendar Icon */}
          <div className="relative flex items-center">
            <input
              type="date"
              value={selectedDate}
              onChange={(e) => setSelectedDate(e.target.value)}
              className="pl-9 pr-3 py-2 text-sm font-semibold bg-white border border-slate-300 rounded-xl shadow-xs focus:ring-2 focus:ring-red-500 focus:outline-none text-slate-800 cursor-pointer"
            />
            <CalendarIcon className="w-4 h-4 text-slate-400 absolute left-3 pointer-events-none" />
          </div>

          {/* Refresh Button */}
          <button
            onClick={() => fetchAttendance(selectedDate)}
            disabled={loading}
            className="p-2.5 bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 rounded-xl shadow-xs transition-colors"
            title="Refresh Data"
          >
            <RotateCcw className={`w-4 h-4 ${loading ? 'animate-spin text-red-600' : ''}`} />
          </button>

          {/* Export Daily CSV Button */}
          <button
            onClick={handleExportDailyCSV}
            disabled={filteredData.length === 0}
            className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-900 hover:bg-slate-800 text-white text-sm font-semibold rounded-xl shadow-xs transition-colors disabled:opacity-50"
          >
            <Download className="w-4 h-4" />
            Export CSV
          </button>
        </div>
      </div>

      {/* Summary Metric Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
        {/* Total Users */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center font-bold">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-slate-500">
              {canViewAll ? 'Total Users' : 'Personal Record'}
            </p>
            <p className="text-2xl font-black text-slate-900 mt-0.5">{summary.total}</p>
          </div>
        </div>

        {/* Present / On-Time */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center font-bold">
            <CheckCircle2 className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-emerald-600">On Time</p>
            <p className="text-2xl font-black text-emerald-700 mt-0.5">{summary.present}</p>
          </div>
        </div>

        {/* Late */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center font-bold">
            <Clock className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-amber-600">Late</p>
            <p className="text-2xl font-black text-amber-700 mt-0.5">{summary.late}</p>
          </div>
        </div>

        {/* On Leave */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-sky-50 text-sky-600 flex items-center justify-center font-bold">
            <CalendarX2 className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-sky-600">On Leave</p>
            <p className="text-2xl font-black text-sky-700 mt-0.5">{summary.leave}</p>
          </div>
        </div>

        {/* Absent / Not Checked In */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4 col-span-2 sm:col-span-1">
          <div className="w-12 h-12 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center font-bold">
            <UserX className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold text-rose-600">Not Checked In</p>
            <p className="text-2xl font-black text-rose-700 mt-0.5">{summary.absent}</p>
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white p-4 rounded-2xl border border-slate-200/80 shadow-xs">
        {/* Search */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search employee name, NIP..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-red-500 transition-all text-slate-800"
          />
        </div>

        {/* Select Dropdowns */}
        <div className="flex flex-wrap items-center gap-3 w-full sm:w-auto">
          {/* Department Filter (Visible when authorized for all) */}
          {canViewAll && (
            <div className="flex items-center gap-1.5">
              <Building2 className="w-4 h-4 text-slate-400" />
              <select
                value={departmentFilter}
                onChange={(e) => setDepartmentFilter(e.target.value)}
                className="px-3 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-red-500 font-medium text-slate-700"
              >
                <option value="ALL">All Departments</option>
                {departments.map((dept) => (
                  <option key={dept} value={dept}>
                    {dept}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Status Filter */}
          <div className="flex items-center gap-1.5">
            <Filter className="w-4 h-4 text-slate-400" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="px-3 py-2 text-sm bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-red-500 font-medium text-slate-700"
            >
              <option value="ALL">All Status</option>
              <option value="PRESENT">Present (On Time)</option>
              <option value="LATE">Late</option>
              <option value="LEAVE">On Leave</option>
              <option value="ABSENT">Not Checked In</option>
            </select>
          </div>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="p-4 bg-rose-50 border border-rose-200 rounded-2xl flex items-center gap-3 text-rose-700 text-sm">
          <AlertCircle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Attendance Table */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/80 border-b border-slate-200 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                <th className="py-4 px-6">Employee</th>
                <th className="py-4 px-6">Department</th>
                <th className="py-4 px-6">Check In</th>
                <th className="py-4 px-6">Check Out</th>
                <th className="py-4 px-6">Location / Notes</th>
                <th className="py-4 px-6 text-center">Status</th>
                <th className="py-4 px-6 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-sm">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-slate-400">
                    <div className="flex flex-col items-center gap-3">
                      <div className="w-8 h-8 border-3 border-red-600 border-t-transparent rounded-full animate-spin" />
                      <span className="font-medium text-slate-500">Loading attendance data...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredData.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-slate-400">
                    <div className="flex flex-col items-center gap-2">
                      <CalendarX2 className="w-10 h-10 text-slate-300 stroke-1" />
                      <p className="font-semibold text-slate-700">No attendance records found</p>
                      <p className="text-xs text-slate-400">
                        Try changing the date filter or clearing your search criteria.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                filteredData.map((item) => (
                  <tr
                    key={item.user_id}
                    onClick={() => handleOpenUserModal(item)}
                    className="hover:bg-red-50/30 transition-colors group cursor-pointer"
                    title="Click to view monthly attendance history"
                  >
                    {/* Employee Profile */}
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-slate-100 text-slate-700 font-bold flex items-center justify-center border border-slate-200 shrink-0 shadow-2xs overflow-hidden">
                          {item.avatar_url ? (
                            <img
                              src={item.avatar_url}
                              alt={item.name}
                              className="w-full h-full object-cover"
                            />
                          ) : (
                            item.name?.charAt(0) || 'U'
                          )}
                        </div>
                        <div className="min-w-0">
                          <p className="font-bold text-slate-900 leading-tight group-hover:text-red-600 transition-colors flex items-center gap-1.5">
                            {item.name}
                            <ExternalLink className="w-3.5 h-3.5 opacity-0 group-hover:opacity-100 text-red-500 transition-opacity" />
                          </p>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className="text-[11px] font-mono text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded">
                              {item.nip || 'No NIP'}
                            </span>
                            <span className="text-xs text-slate-400 truncate max-w-[140px]">
                              {item.email}
                            </span>
                          </div>
                        </div>
                      </div>
                    </td>

                    {/* Department */}
                    <td className="py-4 px-6">
                      <span className="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200/60">
                        {item.department || 'General'}
                      </span>
                    </td>

                    {/* Check In Time */}
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-2">
                        <div
                          className={`w-2 h-2 rounded-full ${
                            item.status === 'LATE'
                              ? 'bg-amber-500'
                              : item.check_in_time
                              ? 'bg-emerald-500'
                              : 'bg-slate-300'
                          }`}
                        />
                        <span
                          className={`font-mono text-sm font-semibold ${
                            item.check_in_time ? 'text-slate-900' : 'text-slate-400'
                          }`}
                        >
                          {formatTime(item.check_in_time)}
                        </span>
                      </div>
                    </td>

                    {/* Check Out Time */}
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-2">
                        <div
                          className={`w-2 h-2 rounded-full ${
                            item.check_out_time ? 'bg-indigo-500' : 'bg-slate-300'
                          }`}
                        />
                        <span
                          className={`font-mono text-sm font-semibold ${
                            item.check_out_time ? 'text-slate-900' : 'text-slate-400'
                          }`}
                        >
                          {formatTime(item.check_out_time)}
                        </span>
                      </div>
                    </td>

                    {/* Location / Notes */}
                    <td className="py-4 px-6">
                      <div className="flex items-start gap-1.5 text-xs text-slate-600 max-w-[220px]">
                        {item.location && item.location !== '-' && (
                          <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0 mt-0.5" />
                        )}
                        <span className="truncate" title={item.location || item.notes}>
                          {item.location || item.notes || '-'}
                        </span>
                      </div>
                    </td>

                    {/* Status Badge */}
                    <td className="py-4 px-6 text-center">
                      {getStatusBadge(item.status)}
                    </td>

                    {/* Action Button */}
                    <td className="py-4 px-6 text-right">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleOpenUserModal(item);
                        }}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-red-600 bg-red-50 hover:bg-red-100 rounded-xl transition-all border border-red-200/60"
                      >
                        <CalendarDays className="w-3.5 h-3.5" />
                        Monthly Log
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Footer */}
        <div className="p-4 bg-slate-50/80 border-t border-slate-200/80 flex flex-col sm:flex-row items-center justify-between text-xs text-slate-500 gap-2">
          <span>
            Showing <strong className="text-slate-800">{filteredData.length}</strong> of{' '}
            <strong className="text-slate-800">{attendanceData.length}</strong> employees for date{' '}
            <strong className="text-slate-900 font-mono">{selectedDate}</strong>
          </span>
          <span className="flex items-center gap-1.5 text-slate-400">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            Click employee row to view monthly logs
          </span>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* Individual Employee Monthly Attendance History Modal                     */}
      {/* ========================================================================= */}
      {selectedUserModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs animate-fade-in">
          <div
            className="bg-white w-full max-w-4xl max-h-[90vh] rounded-3xl shadow-2xl border border-slate-200/80 flex flex-col overflow-hidden animate-scale-in"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="p-6 border-b border-slate-200/80 flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-50/60">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-2xl bg-red-600 text-white font-bold flex items-center justify-center text-lg shadow-md shrink-0">
                  {selectedUserModal.name?.charAt(0) || 'U'}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-extrabold text-slate-900 leading-tight">
                      {selectedUserModal.name}
                    </h2>
                    <span className="px-2 py-0.5 rounded text-[11px] font-mono bg-slate-200 text-slate-700 font-semibold">
                      {selectedUserModal.nip || 'No NIP'}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-slate-500 mt-1">
                    <span className="flex items-center gap-1">
                      <Building2 className="w-3.5 h-3.5 text-slate-400" />
                      {selectedUserModal.department || 'General'}
                    </span>
                    <span>•</span>
                    <span className="flex items-center gap-1 text-slate-600">
                      <Briefcase className="w-3.5 h-3.5 text-slate-400" />
                      {monthlyData?.user?.role || 'Employee'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Month Picker & Close */}
              <div className="flex items-center gap-2">
                {/* Month Navigator */}
                <div className="flex items-center bg-white p-1 rounded-xl border border-slate-300 shadow-2xs">
                  <button
                    onClick={() => shiftModalMonth(-1)}
                    disabled={monthlyLoading}
                    className="p-1.5 hover:bg-slate-100 text-slate-600 hover:text-slate-900 rounded-lg transition-colors"
                    title="Previous Month"
                  >
                    <ChevronLeft className="w-4 h-4" />
                  </button>

                  <input
                    type="month"
                    value={modalMonth}
                    onChange={handleMonthInputChange}
                    className="px-2 py-0.5 text-xs font-bold text-slate-800 bg-transparent border-0 focus:outline-none cursor-pointer"
                  />

                  <button
                    onClick={() => shiftModalMonth(1)}
                    disabled={monthlyLoading}
                    className="p-1.5 hover:bg-slate-100 text-slate-600 hover:text-slate-900 rounded-lg transition-colors"
                    title="Next Month"
                  >
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>

                {/* Export Monthly CSV */}
                <button
                  onClick={handleExportMonthlyCSV}
                  disabled={monthlyLoading || !monthlyData}
                  className="p-2 bg-slate-900 hover:bg-slate-800 text-white rounded-xl shadow-xs transition-colors"
                  title="Export Month CSV"
                >
                  <Download className="w-4 h-4" />
                </button>

                {/* Close Modal Button */}
                <button
                  onClick={handleCloseUserModal}
                  className="p-2 hover:bg-slate-200/80 text-slate-500 hover:text-slate-800 rounded-xl transition-colors"
                  title="Close"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Modal Body */}
            <div className="p-6 overflow-y-auto space-y-6 flex-1">
              {/* Monthly KPI Summary Cards */}
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                  <p className="text-[11px] font-semibold text-emerald-600">On Time</p>
                  <p className="text-xl font-black text-emerald-700 mt-0.5">
                    {monthlyData?.summary?.present ?? 0}
                  </p>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                  <p className="text-[11px] font-semibold text-amber-600">Late Days</p>
                  <p className="text-xl font-black text-amber-700 mt-0.5">
                    {monthlyData?.summary?.late ?? 0}
                  </p>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                  <p className="text-[11px] font-semibold text-sky-600">On Leave</p>
                  <p className="text-xl font-black text-sky-700 mt-0.5">
                    {monthlyData?.summary?.leave ?? 0}
                  </p>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                  <p className="text-[11px] font-semibold text-rose-600">Absent Days</p>
                  <p className="text-xl font-black text-rose-700 mt-0.5">
                    {monthlyData?.summary?.absent ?? 0}
                  </p>
                </div>
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 col-span-2 sm:col-span-1">
                  <p className="text-[11px] font-semibold text-indigo-600 flex items-center gap-1">
                    <Hourglass className="w-3 h-3" />
                    Work Hours
                  </p>
                  <p className="text-xl font-black text-indigo-700 mt-0.5">
                    {monthlyData?.summary?.work_hours_str || '0h 00m'}
                  </p>
                </div>
              </div>

              {/* Error in modal */}
              {monthlyError && (
                <div className="p-4 bg-rose-50 border border-rose-200 rounded-2xl flex items-center gap-3 text-rose-700 text-sm">
                  <AlertCircle className="w-5 h-5 shrink-0" />
                  <span>{monthlyError}</span>
                </div>
              )}

              {/* Monthly Days Table */}
              <div className="border border-slate-200 rounded-2xl overflow-hidden shadow-2xs">
                <div className="max-h-[380px] overflow-y-auto">
                  <table className="w-full text-left border-collapse">
                    <thead className="sticky top-0 bg-slate-100 z-10">
                      <tr className="border-b border-slate-200 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                        <th className="py-3 px-4">Date</th>
                        <th className="py-3 px-4">Day</th>
                        <th className="py-3 px-4">Check In</th>
                        <th className="py-3 px-4">Check Out</th>
                        <th className="py-3 px-4">Duration</th>
                        <th className="py-3 px-4 text-center">Status</th>
                        <th className="py-3 px-4">Location / Notes</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 text-xs">
                      {monthlyLoading ? (
                        <tr>
                          <td colSpan={7} className="py-14 text-center text-slate-400">
                            <div className="flex flex-col items-center gap-2">
                              <div className="w-6 h-6 border-2 border-red-600 border-t-transparent rounded-full animate-spin" />
                              <span>Loading {formatMonthTitle(modalMonth)} records...</span>
                            </div>
                          </td>
                        </tr>
                      ) : !monthlyData || !monthlyData.days || monthlyData.days.length === 0 ? (
                        <tr>
                          <td colSpan={7} className="py-12 text-center text-slate-400">
                            No attendance history recorded for this month.
                          </td>
                        </tr>
                      ) : (
                        monthlyData.days.map((day) => {
                          return (
                            <tr
                              key={day.date}
                              className={`transition-colors ${
                                day.isWeekend
                                  ? 'bg-slate-50/60 text-slate-400'
                                  : 'hover:bg-slate-50/80 text-slate-700'
                              }`}
                            >
                              <td className="py-3 px-4 font-mono font-medium">
                                {day.date}
                              </td>
                              <td className="py-3 px-4 font-semibold">
                                <span
                                  className={
                                    day.isWeekend
                                      ? 'text-slate-400 font-normal'
                                      : 'text-slate-800'
                                  }
                                >
                                  {day.day_name}
                                </span>
                              </td>
                              <td className="py-3 px-4 font-mono">
                                {formatTime(day.check_in_time)}
                              </td>
                              <td className="py-3 px-4 font-mono">
                                {formatTime(day.check_out_time)}
                              </td>
                              <td className="py-3 px-4 font-mono text-slate-600">
                                {day.duration || '-'}
                              </td>
                              <td className="py-3 px-4 text-center">
                                {getStatusBadge(day.status)}
                              </td>
                              <td className="py-3 px-4 max-w-[200px] truncate" title={day.location || day.notes}>
                                {day.location || day.notes || '-'}
                              </td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="p-4 bg-slate-50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-500">
              <span>
                Total Records: <strong>{monthlyData?.days?.length || 0} days</strong> in{' '}
                <strong>{formatMonthTitle(modalMonth)}</strong>
              </span>
              <button
                onClick={handleCloseUserModal}
                className="px-4 py-1.5 bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 font-semibold rounded-xl transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
