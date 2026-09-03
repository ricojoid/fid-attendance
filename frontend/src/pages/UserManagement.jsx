import React, { useState, useEffect, useMemo } from 'react';
import api from '../api/client';
import {
  UserPlus,
  Search,
  Edit2,
  Trash2,
  Shield,
  ShieldCheck,
  X,
  CheckCircle2,
  AlertCircle,
  UserCheck,
  Building2,
  Layers,
  Users,
  UserCog,
  Briefcase,
} from 'lucide-react';

export const MASTER_DEPARTMENTS = [
  'App Dev & Data AI',
  'Service Maintenance',
  'Procurement',
  'Sales',
  'Human Resource',
];

export const MASTER_ROLES = [
  { value: 'SUPER_ADMIN', label: 'Super Admin' },
  { value: 'COUNTRY_HEAD', label: 'Country Head' },
  { value: 'MANAGER', label: 'Manager' },
  { value: 'DEPARTMENT_HEAD', label: 'Dept Head' },
  { value: 'EMPLOYEE', label: 'Employee' },
];

export default function UserManagement() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [departmentFilter, setDepartmentFilter] = useState('ALL');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isMappingModalOpen, setIsMappingModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [mappingUser, setMappingUser] = useState(null);

  const [formData, setFormData] = useState({
    nip: '',
    name: '',
    email: '',
    password: '',
    role: 'EMPLOYEE',
    department: 'App Dev & Data AI',
    birth_date: '',
    approver_name: '',
  });

  const [mappingData, setMappingData] = useState({
    approverUserId: '',
    approverName: '',
  });

  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Helper to find Department Head of a specific department
  const getDeptHeadForDepartment = (deptName, excludeUserId = null) => {
    if (!deptName) return null;
    return users.find((u) => {
      if (excludeUserId && u.id === excludeUserId) return false;
      const isDeptHead = u.role === 'DEPARTMENT_HEAD';
      const isSameDept = (u.department || '').trim().toLowerCase() === deptName.trim().toLowerCase();
      return isDeptHead && isSameDept;
    });
  };

  // Helper to get Managers
  const getManagers = (excludeUserId = null) => {
    return users.filter((u) => {
      if (excludeUserId && u.id === excludeUserId) return false;
      return u.role === 'MANAGER';
    });
  };

  // Helper to get Executives (Country Head / Super Admin)
  const getExecutives = (excludeUserId = null) => {
    return users.filter((u) => {
      if (excludeUserId && u.id === excludeUserId) return false;
      return u.role === 'COUNTRY_HEAD' || u.role === 'SUPER_ADMIN';
    });
  };

  const stats = useMemo(() => {
    const total = users.length;
    const superAdmins = users.filter((u) => u.role === 'SUPER_ADMIN' || u.role === 'COUNTRY_HEAD').length;
    const managersAndHeads = users.filter((u) => u.role === 'MANAGER' || u.role === 'DEPARTMENT_HEAD').length;
    const employees = users.filter((u) => u.role === 'EMPLOYEE' || !u.role).length;
    return { total, superAdmins, managersAndHeads, employees };
  }, [users]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const url = `/admin/users?search=${encodeURIComponent(search)}&department=${encodeURIComponent(departmentFilter)}`;
      const res = await api.get(url);
      setUsers(res.data.data || []);
    } catch (err) {
      console.error('Failed to fetch users', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [search, departmentFilter]);

  const handleDepartmentChange = (newDept) => {
    setFormData((prev) => {
      let updatedApprover = prev.approver_name;
      if (prev.role === 'EMPLOYEE') {
        const deptHead = getDeptHeadForDepartment(newDept, editingUser?.id);
        updatedApprover = deptHead ? deptHead.name : '';
      }
      return {
        ...prev,
        department: newDept,
        approver_name: updatedApprover,
      };
    });
  };

  const handleRoleChange = (newRole) => {
    setFormData((prev) => {
      let updatedApprover = prev.approver_name;
      if (newRole === 'EMPLOYEE') {
        const deptHead = getDeptHeadForDepartment(prev.department, editingUser?.id);
        updatedApprover = deptHead ? deptHead.name : '';
      } else if (newRole === 'DEPARTMENT_HEAD') {
        // If current approver is not a manager, clear it so user selects a manager
        const isManager = users.some(
          (u) => u.role === 'MANAGER' && u.name.toLowerCase() === (updatedApprover || '').toLowerCase()
        );
        if (!isManager) {
          updatedApprover = '';
        }
      } else if (newRole === 'SUPER_ADMIN' || newRole === 'COUNTRY_HEAD') {
        updatedApprover = '';
      }
      return {
        ...prev,
        role: newRole,
        approver_name: updatedApprover,
      };
    });
  };

  const handleOpenModal = (userToEdit = null) => {
    setError('');
    setSuccess('');
    if (userToEdit) {
      setEditingUser(userToEdit);
      const userRole = userToEdit.role || 'EMPLOYEE';
      const userDept = userToEdit.department || 'App Dev & Data AI';

      let approver = userToEdit.approver_name || '';

      // If approver not yet in DB, check localStorage
      if (!approver) {
        const emailKey = (userToEdit.email || '').toLowerCase().trim();
        const nipKey = (userToEdit.nip || '').toLowerCase().trim();
        const idKey = userToEdit.id ? userToEdit.id.toString() : '';
        for (const k of [emailKey, userToEdit.email, nipKey, idKey]) {
          if (k) {
            const direct = localStorage.getItem(`assigned_approver_${k}`) || localStorage.getItem(`flutter.assigned_approver_${k}`);
            if (direct) {
              approver = direct;
              break;
            }
          }
        }
      }

      // Auto-assign to Dept Head if user is EMPLOYEE and approver is empty or not set
      if (userRole === 'EMPLOYEE') {
        const deptHead = getDeptHeadForDepartment(userDept, userToEdit.id);
        if (deptHead) {
          approver = deptHead.name;
        }
      }

      setFormData({
        nip: userToEdit.nip,
        name: userToEdit.name,
        email: userToEdit.email,
        password: '',
        role: userRole,
        department: userDept,
        birth_date: userToEdit.birth_date || '',
        approver_name: approver,
      });
    } else {
      setEditingUser(null);
      const defaultDept = 'App Dev & Data AI';
      const deptHead = getDeptHeadForDepartment(defaultDept);
      setFormData({
        nip: `EMP${Math.floor(100 + Math.random() * 900)}`,
        name: '',
        email: '',
        password: '',
        role: 'EMPLOYEE',
        department: defaultDept,
        birth_date: '',
        approver_name: deptHead ? deptHead.name : '',
      });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingUser(null);
  };

  const handleOpenMappingModal = (user) => {
    setMappingUser(user);
    const emailKey = (user.email || '').toLowerCase().trim();
    const nipKey = (user.nip || '').toLowerCase().trim();
    const idKey = user.id ? user.id.toString() : '';

    let savedStr = null;
    let savedDirect = null;

    for (const k of [emailKey, user.email, nipKey, idKey]) {
      if (k) {
        savedStr = savedStr || localStorage.getItem(`approval_mapping_${k}`) || localStorage.getItem(`flutter.approval_mapping_${k}`);
        savedDirect = savedDirect || localStorage.getItem(`assigned_approver_${k}`) || localStorage.getItem(`flutter.assigned_approver_${k}`);
      }
    }

    let matchedUserId = '';
    let matchedName = user.approver_name || '';

    if (!matchedName && (savedDirect || savedStr)) {
      matchedName = savedDirect || '';
      if (!matchedName && savedStr) {
        try {
          const parsed = JSON.parse(savedStr);
          matchedName = parsed.approverName || '';
        } catch (_) {}
      }
    }

    // Auto-select Dept Head for EMPLOYEE if approver is still empty
    if (!matchedName && (user.role === 'EMPLOYEE' || !user.role)) {
      const deptHead = getDeptHeadForDepartment(user.department, user.id);
      if (deptHead) {
        matchedName = deptHead.name;
        matchedUserId = deptHead.id.toString();
      }
    }

    if (matchedName && !matchedUserId) {
      const foundUser = users.find((u) => u?.name && u.name.toLowerCase() === matchedName.toLowerCase());
      if (foundUser) {
        matchedUserId = (foundUser.id ?? '').toString();
        matchedName = foundUser.name;
      }
    }

    setMappingData({
      approverUserId: matchedUserId,
      approverName: matchedName,
    });
    setIsMappingModalOpen(true);
  };

  const handleSaveMapping = async (e) => {
    e.preventDefault();
    if (!mappingData.approverName) {
      setError('Please select an approver from the dropdown');
      return;
    }

    if (mappingUser) {
      const appName = mappingData.approverName;

      try {
        // Save directly to Backend Database table TB_M_USER
        await api.put(`/admin/users/${mappingUser.id}`, {
          approver_name: appName,
        });

        // Also save to local storage keys for instant Web/Mobile sync
        const payload = JSON.stringify(mappingData);
        const emailKey = (mappingUser.email || '').toLowerCase().trim();
        const nipKey = (mappingUser.nip || '').toLowerCase().trim();
        const idKey = mappingUser.id ? mappingUser.id.toString() : '';

        [emailKey, mappingUser.email, nipKey, idKey].forEach((k) => {
          if (k) {
            localStorage.setItem(`approval_mapping_${k}`, payload);
            localStorage.setItem(`assigned_approver_${k}`, appName);
            localStorage.setItem(`flutter.approval_mapping_${k}`, payload);
            localStorage.setItem(`flutter.assigned_approver_${k}`, appName);
          }
        });

        setSuccess(`Approver for ${mappingUser.name} saved to Database as ${appName}!`);
        setIsMappingModalOpen(false);
        fetchUsers();
      } catch (err) {
        setError(err.response?.data?.error || 'Failed to update approver in DB');
      }
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    try {
      if (editingUser) {
        await api.put(`/admin/users/${editingUser.id}`, formData);
        setSuccess(`User ${formData.name} updated successfully`);
      } else {
        await api.post('/admin/users', formData);
        setSuccess(`User ${formData.name} created successfully`);
      }

      // Sync approver_name to localStorage keys for web & mobile
      const appName = formData.approver_name || '';
      const emailKey = (formData.email || '').toLowerCase().trim();
      const nipKey = (formData.nip || '').toLowerCase().trim();
      const idKey = editingUser?.id ? editingUser.id.toString() : '';

      [emailKey, formData.email, nipKey, idKey].forEach((k) => {
        if (k) {
          if (appName) {
            const payload = JSON.stringify({ approverName: appName });
            localStorage.setItem(`assigned_approver_${k}`, appName);
            localStorage.setItem(`flutter.assigned_approver_${k}`, appName);
            localStorage.setItem(`approval_mapping_${k}`, payload);
            localStorage.setItem(`flutter.approval_mapping_${k}`, payload);
          } else {
            localStorage.removeItem(`assigned_approver_${k}`);
            localStorage.removeItem(`flutter.assigned_approver_${k}`);
            localStorage.removeItem(`approval_mapping_${k}`);
            localStorage.removeItem(`flutter.approval_mapping_${k}`);
          }
        }
      });

      handleCloseModal();
      fetchUsers();
    } catch (err) {
      setError(err.response?.data?.error || 'Operation failed');
    }
  };

  const handleDelete = async (user) => {
    if (!window.confirm(`Are you sure you want to delete user ${user.name}?`)) return;
    try {
      await api.delete(`/admin/users/${user.id}`);
      setSuccess(`User ${user.name} deleted`);
      fetchUsers();
    } catch (err) {
      alert(err.response?.data?.error || 'Failed to delete user');
    }
  };

  const renderRoleBadge = (role) => {
    switch (role) {
      case 'SUPER_ADMIN':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-rose-50 text-rose-700 border border-rose-200 rounded-full text-xs font-semibold">
            <ShieldCheck className="w-3.5 h-3.5" /> Super Admin
          </span>
        );
      case 'COUNTRY_HEAD':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-amber-50 text-amber-700 border border-amber-200 rounded-full text-xs font-semibold">
            <UserCheck className="w-3.5 h-3.5" /> Country Head
          </span>
        );
      case 'MANAGER':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-purple-50 text-purple-700 border border-purple-200 rounded-full text-xs font-semibold">
            <Layers className="w-3.5 h-3.5" /> Manager
          </span>
        );
      case 'DEPARTMENT_HEAD':
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-indigo-50 text-indigo-700 border border-indigo-200 rounded-full text-xs font-semibold">
            <Building2 className="w-3.5 h-3.5" /> Dept Head
          </span>
        );
      case 'EMPLOYEE':
      default:
        return (
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-slate-100 text-slate-700 rounded-full text-xs font-medium">
            <Shield className="w-3.5 h-3.5" /> Employee
          </span>
        );
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Metric Summary Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs card-interactive flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Total Users</p>
            <p className="text-2xl font-black text-slate-900 mt-1">{stats.total}</p>
          </div>
          <div className="w-11 h-11 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700">
            <Users className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs card-interactive flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Executives</p>
            <p className="text-2xl font-black text-rose-600 mt-1">{stats.superAdmins}</p>
          </div>
          <div className="w-11 h-11 rounded-xl bg-rose-50 flex items-center justify-center text-rose-600 border border-rose-100">
            <ShieldCheck className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs card-interactive flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Managers & Heads</p>
            <p className="text-2xl font-black text-indigo-600 mt-1">{stats.managersAndHeads}</p>
          </div>
          <div className="w-11 h-11 rounded-xl bg-indigo-50 flex items-center justify-center text-indigo-600 border border-indigo-100">
            <Building2 className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs card-interactive flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Employees</p>
            <p className="text-2xl font-black text-slate-800 mt-1">{stats.employees}</p>
          </div>
          <div className="w-11 h-11 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700">
            <Briefcase className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Header Actions */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs">
        <div className="flex flex-col sm:flex-row items-center gap-3 w-full sm:w-auto flex-1 max-w-2xl">
          {/* Search Box */}
          <div className="relative w-full sm:w-80">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search name, NIP, email..."
              className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-medium focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-500 transition-all"
            />
          </div>

          {/* Department Filter */}
          <div className="w-full sm:w-56">
            <select
              value={departmentFilter}
              onChange={(e) => setDepartmentFilter(e.target.value)}
              className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-red-500/20 focus:border-red-500 transition-all"
            >
              <option value="ALL">All Departments</option>
              {MASTER_DEPARTMENTS.map((dept) => (
                <option key={dept} value={dept}>
                  {dept}
                </option>
              ))}
            </select>
          </div>
        </div>

        <button
          onClick={() => handleOpenModal()}
          className="w-full sm:w-auto px-5 py-2.5 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-bold text-sm rounded-xl flex items-center justify-center gap-2 transition-all shadow-lg shadow-red-600/25 btn-bounce shrink-0"
        >
          <UserPlus className="w-4 h-4" />
          Add New User
        </button>
      </div>

      {success && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-xl text-sm flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 shrink-0" />
          {success}
        </div>
      )}

      {/* Users Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase tracking-wider text-xs">
              <tr>
                <th className="px-6 py-4 font-semibold">User Info</th>
                <th className="px-6 py-4 font-semibold">NIP</th>
                <th className="px-6 py-4 font-semibold">Birth Date</th>
                <th className="px-6 py-4 font-semibold">Department</th>
                <th className="px-6 py-4 font-semibold">Role</th>
                <th className="px-6 py-4 font-semibold">Approver</th>
                <th className="px-6 py-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr>
                  <td colSpan="7" className="px-6 py-8 text-center text-slate-400">Loading users...</td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-8 text-center text-slate-400">No users found.</td>
                </tr>
              ) : (
                users.map((u) => {
                  const emailKey = (u.email || '').toLowerCase().trim();
                  const nipKey = (u.nip || '').toLowerCase().trim();
                  const idKey = u.id ? u.id.toString() : '';

                  const deptHead = getDeptHeadForDepartment(u.department, u.id);
                  let approverName = u.approver_name || null;
                  if (!approverName) {
                    for (const k of [emailKey, u.email, nipKey, idKey]) {
                      if (k) {
                        const direct = localStorage.getItem(`assigned_approver_${k}`) || localStorage.getItem(`flutter.assigned_approver_${k}`);
                        const mapStr = localStorage.getItem(`approval_mapping_${k}`) || localStorage.getItem(`flutter.approval_mapping_${k}`);
                        if (direct) {
                          approverName = direct;
                          break;
                        }
                        if (mapStr) {
                          try {
                            const parsed = JSON.parse(mapStr);
                            if (parsed.approverName) {
                              approverName = parsed.approverName;
                              break;
                            }
                          } catch (_) {}
                        }
                      }
                    }
                  }

                  if (!approverName && (u.role === 'EMPLOYEE' || !u.role) && deptHead) {
                    approverName = deptHead.name;
                  }

                  const hasApprover = Boolean(approverName);

                  return (
                    <tr key={u.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-red-50 text-red-700 font-semibold flex items-center justify-center text-sm border border-red-200">
                            {u.name ? u.name.charAt(0).toUpperCase() : 'U'}
                          </div>
                          <div>
                            <p className="font-semibold text-slate-900">{u.name}</p>
                            <p className="text-xs text-slate-500">{u.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 font-medium text-slate-700">{u.nip}</td>
                      <td className="px-6 py-4 text-slate-600 font-medium">{u.birth_date || '-'}</td>
                      <td className="px-6 py-4 text-slate-600">{u.department || 'General'}</td>
                      <td className="px-6 py-4">{renderRoleBadge(u.role)}</td>
                      <td className="px-6 py-4">
                        <button
                          onClick={() => handleOpenMappingModal(u)}
                          className={`inline-flex items-center gap-1.5 px-3 py-1 border rounded-lg text-xs font-medium transition-colors ${
                            hasApprover
                              ? 'bg-slate-100 hover:bg-red-50 text-slate-700 hover:text-red-600 border-slate-200 hover:border-red-200'
                              : 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100'
                          }`}
                        >
                          <UserCheck className="w-3.5 h-3.5 text-red-600" />
                          <span>{hasApprover ? approverName : 'Not Set'}</span>
                        </button>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleOpenMappingModal(u)}
                            className="p-1.5 text-slate-500 hover:text-red-600 hover:bg-slate-100 rounded-md transition-colors"
                            title="Set Approver"
                          >
                            <UserCheck className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleOpenModal(u)}
                            className="p-1.5 text-slate-500 hover:text-red-600 hover:bg-slate-100 rounded-md transition-colors"
                            title="Edit User"
                          >
                            <Edit2 className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleDelete(u)}
                            className="p-1.5 text-slate-500 hover:text-rose-600 hover:bg-slate-100 rounded-md transition-colors"
                            title="Delete User"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add / Edit User Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
              <h3 className="font-bold text-slate-900 text-lg">
                {editingUser ? 'Edit User' : 'Add New User'}
              </h3>
              <button onClick={handleCloseModal} className="p-1 text-slate-400 hover:text-slate-600 rounded-md">
                <X className="w-5 h-5" />
              </button>
            </div>

            {error && (
              <div className="p-3 bg-rose-50 border border-rose-200 text-rose-600 rounded-lg text-xs font-medium flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">NIP</label>
                <input
                  type="text"
                  required
                  value={formData.nip}
                  onChange={(e) => setFormData({ ...formData, nip: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">Full Name</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">Email</label>
                <input
                  type="email"
                  required
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">
                  Password {editingUser && '(Leave blank to keep unchanged)'}
                </label>
                <input
                  type="password"
                  required={!editingUser}
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm"
                  placeholder={editingUser ? '••••••••' : 'Enter password'}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">Role</label>
                  <select
                    value={formData.role}
                    onChange={(e) => handleRoleChange(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900"
                  >
                    <option value="EMPLOYEE">Employee</option>
                    <option value="DEPARTMENT_HEAD">Dept Head</option>
                    <option value="MANAGER">Manager</option>
                    <option value="COUNTRY_HEAD">Country Head</option>
                    <option value="SUPER_ADMIN">Super Admin</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">Department</label>
                  <select
                    value={formData.department}
                    onChange={(e) => handleDepartmentChange(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900 focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
                  >
                    {MASTER_DEPARTMENTS.map((dept) => (
                      <option key={dept} value={dept}>
                        {dept}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Approver Selection */}
              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">
                  Approver
                </label>
                {formData.role === 'EMPLOYEE' ? (
                  <select
                    value={formData.approver_name}
                    onChange={(e) => setFormData({ ...formData, approver_name: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900 focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
                  >
                    <option value="">-- Select Approver --</option>
                    {getDeptHeadForDepartment(formData.department, editingUser?.id) && (
                      <option value={getDeptHeadForDepartment(formData.department, editingUser?.id).name}>
                        {getDeptHeadForDepartment(formData.department, editingUser?.id).name} (Dept Head - {formData.department})
                      </option>
                    )}
                    {users
                      .filter(
                        (u) =>
                          u.id !== editingUser?.id &&
                          (u.role === 'DEPARTMENT_HEAD' || u.role === 'MANAGER') &&
                          u.name !== getDeptHeadForDepartment(formData.department, editingUser?.id)?.name
                      )
                      .map((u) => (
                        <option key={u.id} value={u.name}>
                          {u.name} ({u.role === 'DEPARTMENT_HEAD' ? 'Dept Head' : u.role} - {u.department || 'General'})
                        </option>
                      ))}
                  </select>
                ) : formData.role === 'DEPARTMENT_HEAD' ? (
                  <select
                    value={formData.approver_name}
                    onChange={(e) => setFormData({ ...formData, approver_name: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900 focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
                  >
                    <option value="">-- Select Manager --</option>
                    {getManagers(editingUser?.id).map((m) => (
                      <option key={m.id} value={m.name}>
                        {m.name} (Manager - {m.department || 'General'})
                      </option>
                    ))}
                  </select>
                ) : formData.role === 'MANAGER' ? (
                  <select
                    value={formData.approver_name}
                    onChange={(e) => setFormData({ ...formData, approver_name: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900 focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
                  >
                    <option value="">-- Select Approver --</option>
                    {getExecutives(editingUser?.id).map((ex) => (
                      <option key={ex.id} value={ex.name}>
                        {ex.name} ({ex.role})
                      </option>
                    ))}
                  </select>
                ) : (
                  <select
                    value={formData.approver_name}
                    onChange={(e) => setFormData({ ...formData, approver_name: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900 focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
                  >
                    <option value="">-- None --</option>
                  </select>
                )}
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">Date of Birth</label>
                <input
                  type="date"
                  value={formData.birth_date}
                  onChange={(e) => setFormData({ ...formData, birth_date: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={handleCloseModal}
                  className="px-4 py-2 text-sm text-slate-600 hover:bg-slate-100 rounded-lg font-medium"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-medium text-sm rounded-lg transition-all shadow-md shadow-red-600/20"
                >
                  {editingUser ? 'Update User' : 'Save User'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Select Approver Modal */}
      {isMappingModalOpen && mappingUser && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
              <div>
                <h3 className="font-bold text-slate-900 text-lg">Select Approver</h3>
                <p className="text-xs text-slate-500">For user: <strong className="text-slate-800">{mappingUser.name}</strong></p>
              </div>
              <button onClick={() => setIsMappingModalOpen(false)} className="p-1 text-slate-400 hover:text-slate-600 rounded-md">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveMapping} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 uppercase mb-1">
                  Approver
                </label>

                <select
                  value={mappingData.approverUserId}
                  onChange={(e) => {
                    const selectedUser = users.find((u) => u.id.toString() === e.target.value);
                    setMappingData({
                      approverUserId: e.target.value,
                      approverName: selectedUser ? selectedUser.name : '',
                    });
                  }}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm font-medium text-slate-900 focus:ring-2 focus:ring-red-500/20 focus:border-red-500"
                >
                  <option value="">-- Select Approver --</option>
                  {mappingUser.role === 'DEPARTMENT_HEAD' ? (
                    getManagers(mappingUser.id).map((m) => (
                      <option key={m.id} value={m.id}>
                        {m.name} (Manager - {m.department || 'General'})
                      </option>
                    ))
                  ) : (
                    <>
                      {getDeptHeadForDepartment(mappingUser.department, mappingUser.id) && (
                        <option value={getDeptHeadForDepartment(mappingUser.department, mappingUser.id).id}>
                          {getDeptHeadForDepartment(mappingUser.department, mappingUser.id).name} (Dept Head - {mappingUser.department})
                        </option>
                      )}
                      {users
                        .filter(
                          (u) =>
                            u.id !== mappingUser.id &&
                            u.id !== getDeptHeadForDepartment(mappingUser.department, mappingUser.id)?.id
                        )
                        .map((u) => (
                          <option key={u.id} value={u.id}>
                            {u.name} ({u.role})
                          </option>
                        ))}
                    </>
                  )}
                </select>
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsMappingModalOpen(false)}
                  className="px-4 py-2 text-sm text-slate-600 hover:bg-slate-100 rounded-lg font-medium"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-red-600 hover:bg-red-700 active:bg-red-800 text-white font-medium text-sm rounded-lg transition-all shadow-md shadow-red-600/20"
                >
                  Save Approver
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
