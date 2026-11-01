package controllers

import (
	"strings"
	"testing"

	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

func testDirectory(users []models.User) *approverDirectory {
	d := &approverDirectory{byID: map[uint]*models.User{}, byName: map[string]*models.User{}, users: users}
	for i := range d.users {
		u := &d.users[i]
		d.byID[u.ID] = u
		if _, ok := d.byName[strings.ToLower(u.Name)]; !ok {
			d.byName[strings.ToLower(u.Name)] = u
		}
	}
	return d
}

func TestApproverRouting(t *testing.T) {
	d := testDirectory([]models.User{
		{ID: 1, Name: "Admin", Role: models.RoleSuperAdmin},
		{ID: 2, Name: "Country Head", Role: models.RoleCountryHead},
		{ID: 3, Name: "Manager AppDev", Role: models.RoleManager, Department: "App Dev"},
		{ID: 4, Name: "Dina", Role: models.RoleDepartmentHead, Department: "App Dev"},
		{ID: 5, Name: "Rico", Role: models.RoleEmployee, Department: "App Dev", ApproverName: "Dina"},
		{ID: 6, Name: "Di", Role: models.RoleEmployee, Department: "App Dev"},
		{ID: 7, Name: "Sly", Role: models.RoleEmployee, Department: "App Dev", ApproverName: "Sly"},
		{ID: 8, Name: "Lone", Role: models.RoleEmployee, Department: "Sales"},
	})
	cases := map[uint]uint{
		5: 4, // explicit mapping
		4: 3, // dept head → manager of dept
		3: 2, // manager → country head
		7: 4, // self-mapping ignored → dept head
		8: 2, // no dept head/manager in Sales → country head
	}
	for sub, want := range cases {
		if got := d.Resolve(d.byID[sub]); got == nil || got.ID != want {
			t.Errorf("submitter %d: want approver %d, got %+v", sub, want, got)
		}
	}
	// "Di" must not be able to approve Rico just because "dina" contains "di".
	if d.CanProcess(d.byID[6], d.byID[5]) {
		t.Errorf("substring name match must not grant approval")
	}
	if d.CanProcess(d.byID[7], d.byID[7]) {
		t.Errorf("self approval must be denied")
	}
	if !d.CanProcess(d.byID[1], d.byID[5]) {
		t.Errorf("super admin can process any request")
	}
}
