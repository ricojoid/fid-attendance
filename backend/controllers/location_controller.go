package controllers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"gorm.io/gorm"
)

// scopedUsersQuery limits users to what the requester may see — the same
// hierarchy rules as the attendance monitoring dashboard.
func scopedUsersQuery(requester models.User) *gorm.DB {
	q := config.DB.Model(&models.User{})
	if canViewAllAttendance(requester) {
		return q
	}
	role := strings.ToUpper(strings.TrimSpace(requester.Role))
	dept := strings.TrimSpace(requester.Department)
	switch role {
	case models.RoleManager:
		return q.Where("LOWER(department) = LOWER(?)", dept)
	case models.RoleDepartmentHead:
		return q.Where("LOWER(department) = LOWER(?) AND (UPPER(role) = 'EMPLOYEE' OR id = ?)", dept, requester.ID)
	default:
		return q.Where("id = ?", requester.ID)
	}
}

type mapPoint struct {
	AttendanceID uint      `json:"attendance_id"`
	UserID       uint      `json:"user_id"`
	Name         string    `json:"name"`
	NIP          string    `json:"nip"`
	Department   string    `json:"department"`
	Role         string    `json:"role"`
	AvatarURL    string    `json:"avatar_url,omitempty"`
	AvatarFrame  string    `json:"avatar_frame,omitempty"`
	TopBadge     *TopBadge `json:"top_badge,omitempty"`
	Date         string    `json:"date"`
	Status       string    `json:"status"`
	Source       string    `json:"source"`
	CheckIn      *mapStop  `json:"check_in"`
	CheckOut     *mapStop  `json:"check_out"`
	WorkMinutes  int       `json:"work_minutes"`
}

type mapStop struct {
	Time     *time.Time `json:"time"`
	Lat      float64    `json:"lat"`
	Long     float64    `json:"long"`
	Address  string     `json:"address"`
	Accuracy float64    `json:"accuracy"`
	Note     string     `json:"note"`
}

// GET /attendance/map
//
//	?date=YYYY-MM-DD                      → everyone in scope on that day
//	?user_id=ID&from=YYYY-MM-DD&to=...    → one person over a period (max 93 days)
func GetAttendanceMap(c *gin.Context) {
	requesterID := c.MustGet("userID").(uint)
	var requester models.User
	if err := config.DB.First(&requester, requesterID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	usersQ := scopedUsersQuery(requester)
	attQ := config.DB.Model(&models.Attendance{})
	mode := "DAY"

	if uidStr := strings.TrimSpace(c.Query("user_id")); uidStr != "" {
		uid, err := strconv.ParseUint(uidStr, 10, 64)
		if err != nil || uid == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user_id"})
			return
		}
		var target models.User
		if err := config.DB.First(&target, uid).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		if !canViewTargetAttendance(requester, target) {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not allowed to view this employee's locations"})
			return
		}
		now := time.Now()
		from := c.DefaultQuery("from", now.AddDate(0, 0, -30).Format(dateLayout))
		to := c.DefaultQuery("to", now.Format(dateLayout))
		f, e1 := time.Parse(dateLayout, from)
		t, e2 := time.Parse(dateLayout, to)
		if e1 != nil || e2 != nil || t.Before(f) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "from/to must be YYYY-MM-DD and from <= to"})
			return
		}
		if t.Sub(f) > 93*24*time.Hour {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Range is limited to 3 months"})
			return
		}
		usersQ = config.DB.Model(&models.User{}).Where("id = ?", uid)
		attQ = attQ.Where("user_id = ? AND date >= ? AND date <= ?", uid, from, to)
		mode = "USER"
	} else {
		date := c.DefaultQuery("date", time.Now().Format(dateLayout))
		if _, err := time.Parse(dateLayout, date); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "date must be YYYY-MM-DD"})
			return
		}
		attQ = attQ.Where("date = ?", date)
	}

	var users []models.User
	if mode == "DAY" {
		// The day view may include the whole company: skip heavy base64 avatars.
		usersQ = usersQ.Omit("avatar_url", "password_hash")
	}
	if err := usersQ.Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load users"})
		return
	}
	byID := make(map[uint]*models.User, len(users))
	ids := make([]uint, 0, len(users))
	for i := range users {
		byID[users[i].ID] = &users[i]
		ids = append(ids, users[i].ID)
	}
	if len(ids) == 0 {
		c.JSON(http.StatusOK, gin.H{"mode": mode, "points": []mapPoint{}, "missing": []gin.H{}})
		return
	}

	var rows []models.Attendance
	if err := attQ.Where("user_id IN ?", ids).Order("date asc, check_in_time asc").Find(&rows).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load attendance"})
		return
	}
	tops := topBadgesFor(ids)
	// Full avatars are only sent in single-user mode; the day view can include
	// the whole company, so it stays lightweight (initials on the map).
	withAvatars := mode == "USER"

	points := make([]mapPoint, 0, len(rows))
	seen := map[uint]bool{}
	for _, a := range rows {
		u := byID[a.UserID]
		if u == nil {
			continue
		}
		seen[a.UserID] = true
		p := mapPoint{
			AttendanceID: a.ID, UserID: u.ID, Name: u.Name, NIP: u.NIP, Department: u.Department, Role: u.Role,
			TopBadge: tops[u.ID], Date: a.Date, Status: a.Status, Source: a.Source, AvatarFrame: u.AvatarFrame,
		}
		if withAvatars {
			p.AvatarURL = u.AvatarURL
		}
		if a.CheckInTime != nil && (a.CheckInLat != 0 || a.CheckInLong != 0) {
			p.CheckIn = &mapStop{Time: a.CheckInTime, Lat: a.CheckInLat, Long: a.CheckInLong, Address: a.CheckInAddress, Accuracy: a.CheckInAccuracy, Note: a.CheckInNote}
		}
		if a.CheckOutTime != nil && (a.CheckOutLat != 0 || a.CheckOutLong != 0) {
			p.CheckOut = &mapStop{Time: a.CheckOutTime, Lat: a.CheckOutLat, Long: a.CheckOutLong, Address: a.CheckOutAddress, Accuracy: a.CheckOutAccuracy, Note: a.CheckOutNote}
		}
		if a.CheckInTime != nil && a.CheckOutTime != nil {
			p.WorkMinutes = int(a.CheckOutTime.Sub(*a.CheckInTime).Minutes())
		}
		points = append(points, p)
	}

	// People in scope without a record that day (shown in the side list).
	missing := []gin.H{}
	if mode == "DAY" {
		for _, u := range users {
			if !seen[u.ID] {
				missing = append(missing, gin.H{"user_id": u.ID, "name": u.Name, "department": u.Department, "top_badge": tops[u.ID]})
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{"mode": mode, "points": points, "missing": missing})
}
