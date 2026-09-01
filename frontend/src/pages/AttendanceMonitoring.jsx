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
  AlertCircle
} from 'lucide-react';

export default function AttendanceMonitoring() {
  // Default to today in YYYY-MM-DD format
  const getTodayStr = () => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const [selectedDate, setSelectedDate] = useState(getTodayStr());
  const [attendanceData, setAttendanceData] = useState([]);
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

  // Fetch attendance list for selected date
  const fetchAttendance = async (date) => {
    try {
      setLoading(true);
      setError('');
      const res = await api.get(`/attendance/all?date=${date}`);
      const payload = res.data;
      setAttendanceData(payload.data || []);
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

  // Date Navigation Helpers
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

  // Export to CSV
  const handleExportCSV = () => {
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
    link.setAttribute('download', `Attendance_Report_${selectedDate}.csv`);
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

  return (
    <div className="space-y-6">
      {/* Header with Title & Date Selector */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-extrabold text-slate-900 tracking-tight">
              Attendance Monitoring
            </h1>
            <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-red-50 text-red-700 border border-red-200">
              All Users
            </span>
          </div>
          <p className="text-sm text-slate-500 mt-1">
            Real-time daily presence, check-in/out timestamps, and attendance status.
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

          {/* Export CSV Button */}
          <button
            onClick={handleExportCSV}
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
            <p className="text-xs font-semibold text-slate-500">Total Users</p>
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
          {/* Department Filter */}
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
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-sm">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-16 text-center text-slate-400">
                    <div className="flex flex-col items-center gap-3">
                      <div className="w-8 h-8 border-3 border-red-600 border-t-transparent rounded-full animate-spin" />
                      <span className="font-medium text-slate-500">Loading attendance data...</span>
                    </div>
                  </td>
                </tr>
              ) : filteredData.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-16 text-center text-slate-400">
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
                    className="hover:bg-slate-50/80 transition-colors group"
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
                          <p className="font-bold text-slate-900 leading-tight group-hover:text-red-600 transition-colors">
                            {item.name}
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
                      <div className="flex items-start gap-1.5 text-xs text-slate-600 max-w-[240px]">
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
            Live Attendance Sync
          </span>
        </div>
      </div>
    </div>
  );
}
