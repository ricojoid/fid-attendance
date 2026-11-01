package controllers

import (
	"strings"

	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

// Approval routing — who receives a leave / correction request.
//
//  1. The approver explicitly mapped on the submitter (approver_name), as long
//     as it resolves to an existing user who is not the submitter.
//  2. Otherwise fall back up the org hierarchy:
//     EMPLOYEE        → Department Head of the same department → Manager of the same department
//     DEPARTMENT_HEAD → Manager of the same department
//     MANAGER         → Country Head
//     COUNTRY_HEAD    → Super Admin
//  3. Super Admin can always see and process every pending request.
//
// All users are loaded once per call site and resolved in memory, so listing
// N requests costs a constant number of queries.
type approverDirectory struct {
	byID   map[uint]*models.User
	byName map[string]*models.User // lower(name) → first user with that name
	users  []models.User
}

func loadApproverDirectory() *approverDirectory {
	var users []models.User
	config.DB.Select("id, name, role, department, approver_name").Order("id asc").Find(&users)
	d := &approverDirectory{byID: map[uint]*models.User{}, byName: map[string]*models.User{}, users: users}
	for i := range d.users {
		u := &d.users[i]
		d.byID[u.ID] = u
		key := strings.ToLower(strings.TrimSpace(u.Name))
		if _, ok := d.byName[key]; !ok {
			d.byName[key] = u
		}
	}
	return d
}

func (d *approverDirectory) firstWithRole(role, department string, exclude uint) *models.User {
	for i := range d.users {
		u := &d.users[i]
		if u.ID == exclude || !strings.EqualFold(u.Role, role) {
			continue
		}
		if department != "" && !strings.EqualFold(strings.TrimSpace(u.Department), strings.TrimSpace(department)) {
			continue
		}
		return u
	}
	return nil
}

// Resolve returns the user who should approve requests submitted by `submitter`.
func (d *approverDirectory) Resolve(submitter *models.User) *models.User {
	if submitter == nil {
		return nil
	}
	if name := strings.ToLower(strings.TrimSpace(submitter.ApproverName)); name != "" {
		if u, ok := d.byName[name]; ok && u.ID != submitter.ID {
			return u
		}
	}

	dept := submitter.Department
	switch strings.ToUpper(strings.TrimSpace(submitter.Role)) {
	case models.RoleEmployee, "":
		if u := d.firstWithRole(models.RoleDepartmentHead, dept, submitter.ID); u != nil {
			return u
		}
		if u := d.firstWithRole(models.RoleManager, dept, submitter.ID); u != nil {
			return u
		}
	case models.RoleDepartmentHead:
		if u := d.firstWithRole(models.RoleManager, dept, submitter.ID); u != nil {
			return u
		}
	case models.RoleManager:
		if u := d.firstWithRole(models.RoleCountryHead, "", submitter.ID); u != nil {
			return u
		}
	}
	// Last resort: Country Head, then Super Admin, so no request is ever orphaned.
	if u := d.firstWithRole(models.RoleCountryHead, "", submitter.ID); u != nil {
		return u
	}
	return d.firstWithRole(models.RoleSuperAdmin, "", submitter.ID)
}

// CanProcess reports whether `actor` may approve/reject a request from `submitter`.
func (d *approverDirectory) CanProcess(actor *models.User, submitter *models.User) bool {
	if actor == nil || submitter == nil {
		return false
	}
	if actor.ID == submitter.ID {
		return false // nobody approves their own request
	}
	if strings.EqualFold(actor.Role, models.RoleSuperAdmin) {
		return true
	}
	if a := d.Resolve(submitter); a != nil && a.ID == actor.ID {
		return true
	}
	return false
}

// resolveApproverFor is a convenience for single lookups (submit flows, /auth/me).
func resolveApproverFor(user *models.User) *models.User {
	return loadApproverDirectory().Resolve(user)
}
