package controllers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

type CheckInRequest struct {
	Lat     float64 `json:"lat" binding:"required"`
	Long    float64 `json:"long" binding:"required"`
	Address string  `json:"address"`
}

type CheckOutRequest struct {
	Lat     float64 `json:"lat" binding:"required"`
	Long    float64 `json:"long" binding:"required"`
	Address string  `json:"address"`
}

type CorrectionRequest struct {
	AttendanceDate   string `json:"attendance_date" binding:"required"` // YYYY-MM-DD
	CorrectedCheckIn  string `json:"corrected_check_in"`                // HH:MM or ISO
	CorrectedCheckOut string `json:"corrected_check_out"`               // HH:MM or ISO
	Reason           string `json:"reason" binding:"required"`
}

func CheckIn(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req CheckInRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Latitude and Longitude are required"})
		return
	}

	today := time.Now().Format("2006-01-02")
	now := time.Now()

	var existing models.Attendance
	err := config.DB.Where("user_id = ? AND date = ?", userID, today).First(&existing).Error
	if err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "You have already checked in today", "data": existing})
		return
	}

	// Status calculation (e.g. after 08:30 is LATE)
	status := "PRESENT"
	if now.Hour() > 8 || (now.Hour() == 8 && now.Minute() > 30) {
		status = "LATE"
	}

	attendance := models.Attendance{
		UserID:         userID,
		Date:           today,
		CheckInTime:    &now,
		CheckInLat:     req.Lat,
		CheckInLong:    req.Long,
		CheckInAddress: req.Address,
		Status:         status,
	}

	if err := config.DB.Create(&attendance).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record check-in"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Check-in successful", "data": attendance})
}

func CheckOut(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req CheckOutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Latitude and Longitude are required"})
		return
	}

	today := time.Now().Format("2006-01-02")
	now := time.Now()

	var attendance models.Attendance
	err := config.DB.Where("user_id = ? AND date = ?", userID, today).First(&attendance).Error
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No check-in record found for today"})
		return
	}

	if attendance.CheckOutTime != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "You have already checked out today"})
		return
	}

	attendance.CheckOutTime = &now
	attendance.CheckOutLat = req.Lat
	attendance.CheckOutLong = req.Long
	attendance.CheckOutAddress = req.Address

	if err := config.DB.Save(&attendance).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record check-out"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Check-out successful", "data": attendance})
}

func GetTodayStatus(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	today := time.Now().Format("2006-01-02")

	var attendance models.Attendance
	err := config.DB.Where("user_id = ? AND date = ?", userID, today).First(&attendance).Error
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"has_checked_in": false, "has_checked_out": false, "data": nil})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"has_checked_in":  attendance.CheckInTime != nil,
		"has_checked_out": attendance.CheckOutTime != nil,
		"data":            attendance,
	})
}

func GetAttendanceHistory(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var history []models.Attendance
	if err := config.DB.Where("user_id = ?", userID).Order("date desc").Limit(30).Find(&history).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch attendance history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": history})
}

func parseCorrectionTime(attendanceDate, rawTime string) *time.Time {
	rawTime = strings.TrimSpace(rawTime)
	attendanceDate = strings.TrimSpace(attendanceDate)
	if rawTime == "" {
		return nil
	}

	// 1. Try RFC3339
	if t, err := time.Parse(time.RFC3339, rawTime); err == nil {
		return &t
	}

	// 2. Try parsing full datetime "2006-01-02 15:04:05" or "2006-01-02 15:04"
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", rawTime, time.Local); err == nil {
		return &t
	}
	if t, err := time.ParseInLocation("2006-01-02 15:04", rawTime, time.Local); err == nil {
		return &t
	}

	// 3. If rawTime is only time (e.g. "08:00" or "08:00:00") or contains a date part
	timeOnly := rawTime
	if parts := strings.Fields(rawTime); len(parts) >= 2 {
		timeOnly = parts[len(parts)-1]
		if len(parts[0]) == 10 && strings.Contains(parts[0], "-") {
			attendanceDate = parts[0]
		}
	}

	combined := fmt.Sprintf("%s %s", attendanceDate, timeOnly)
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", combined, time.Local); err == nil {
		return &t
	}
	if t, err := time.ParseInLocation("2006-01-02 15:04", combined, time.Local); err == nil {
		return &t
	}

	return nil
}

func RequestCorrection(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req CorrectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	correctedIn := parseCorrectionTime(req.AttendanceDate, req.CorrectedCheckIn)
	correctedOut := parseCorrectionTime(req.AttendanceDate, req.CorrectedCheckOut)

	correction := models.AttendanceCorrection{
		UserID:            userID,
		AttendanceDate:    req.AttendanceDate,
		CorrectedCheckIn:  correctedIn,
		CorrectedCheckOut: correctedOut,
		Reason:            req.Reason,
		Status:            "PENDING",
	}

	if err := config.DB.Create(&correction).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit attendance correction request"})
		return
	}

	var user models.User
	config.DB.First(&user, userID)

	// 1. Notification for submitter user
	notifSubmitter := models.Notification{
		UserID:    userID,
		Title:     "Attendance Correction Submitted: PENDING",
		Message:   fmt.Sprintf("Your attendance correction for date %s has been submitted successfully.", req.AttendanceDate),
		Type:      "ATTENDANCE",
		Status:    "PENDING",
		CreatedAt: time.Now(),
	}
	config.DB.Create(&notifSubmitter)

	// 2. Notification for approver user if assigned
	if user.ApproverName != "" {
		var approverUser models.User
		if err := config.DB.Where("LOWER(name) = LOWER(?)", strings.TrimSpace(user.ApproverName)).First(&approverUser).Error; err == nil {
			notifApprover := models.Notification{
				UserID:    approverUser.ID,
				Title:     "Approval Request: Attendance Correction",
				Message:   fmt.Sprintf("%s has submitted an attendance correction for date %s needing your approval.", user.Name, req.AttendanceDate),
				Type:      "ATTENDANCE",
				Status:    "PENDING",
				CreatedAt: time.Now(),
			}
			config.DB.Create(&notifApprover)
		}
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Attendance correction submitted successfully", "data": correction})
}

func GetCorrectionHistory(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var list []models.AttendanceCorrection
	if err := config.DB.Where("user_id = ?", userID).Order("id desc").Find(&list).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch correction requests"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": list})
}

func canViewAllAttendance(user models.User) bool {
	roleUpper := strings.ToUpper(strings.TrimSpace(user.Role))
	deptUpper := strings.ToUpper(strings.TrimSpace(user.Department))
	return roleUpper == "SUPER_ADMIN" || strings.Contains(roleUpper, "ADMIN") || deptUpper == "HUMAN RESOURCES" || deptUpper == "HR"
}

func GetAllUsersAttendance(c *gin.Context) {
	requesterID := c.MustGet("userID").(uint)
	var requester models.User
	if err := config.DB.First(&requester, requesterID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	canViewAll := canViewAllAttendance(requester)

	dateStr := strings.TrimSpace(c.Query("date"))
	if dateStr == "" {
		dateStr = time.Now().Format("2006-01-02")
	}

	// 1. Fetch users (if non-Admin and non-HR, only fetch requester themselves)
	var users []models.User
	query := config.DB.Order("name asc")
	if !canViewAll {
		query = query.Where("id = ?", requesterID)
	}
	if err := query.Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
		return
	}

	// 2. Fetch all attendances for the date
	var attendances []models.Attendance
	config.DB.Where("date = ?", dateStr).Find(&attendances)
	attMap := make(map[uint]models.Attendance)
	for _, att := range attendances {
		attMap[att.UserID] = att
	}

	// 3. Fetch approved leaves covering the date
	var leaves []models.LeaveRequest
	config.DB.Preload("LeaveType").Where("status = 'APPROVED' AND start_date <= ? AND end_date >= ?", dateStr, dateStr).Find(&leaves)
	leaveMap := make(map[uint]models.LeaveRequest)
	for _, l := range leaves {
		leaveMap[l.UserID] = l
	}

	// 4. Combine into result list
	type UserAttendanceItem struct {
		UserID       uint       `json:"user_id"`
		Name         string     `json:"name"`
		NIP          string     `json:"nip"`
		Email        string     `json:"email"`
		Department   string     `json:"department"`
		AvatarURL    string     `json:"avatar_url"`
		Date         string     `json:"date"`
		Status       string     `json:"status"` // PRESENT, LATE, LEAVE, ABSENT
		CheckInTime  *time.Time `json:"check_in_time"`
		CheckOutTime *time.Time `json:"check_out_time"`
		Location     string     `json:"location"`
		Notes        string     `json:"notes"`
	}

	var results []UserAttendanceItem
	presentCount := 0
	lateCount := 0
	leaveCount := 0
	absentCount := 0

	for _, u := range users {
		item := UserAttendanceItem{
			UserID:     u.ID,
			Name:       u.Name,
			NIP:        u.NIP,
			Email:      u.Email,
			Department: u.Department,
			AvatarURL:  u.AvatarURL,
			Date:       dateStr,
		}

		if att, exists := attMap[u.ID]; exists {
			item.Status = strings.ToUpper(att.Status)
			if item.Status == "" {
				item.Status = "PRESENT"
			}
			item.CheckInTime = att.CheckInTime
			item.CheckOutTime = att.CheckOutTime
			item.Location = att.CheckInAddress
			item.Notes = att.CheckInAddress

			if item.Status == "LATE" {
				lateCount++
			} else {
				presentCount++
			}
		} else if leave, exists := leaveMap[u.ID]; exists {
			item.Status = "LEAVE"
			leaveTitle := "Leave"
			if leave.LeaveType != nil && leave.LeaveType.Name != "" {
				leaveTitle = leave.LeaveType.Name
			}
			item.Location = fmt.Sprintf("On %s", leaveTitle)
			item.Notes = leave.Reason
			leaveCount++
		} else {
			item.Status = "ABSENT"
			item.Location = "-"
			item.Notes = "Not checked in yet"
			absentCount++
		}

		results = append(results, item)
	}

	c.JSON(http.StatusOK, gin.H{
		"date":         dateStr,
		"can_view_all": canViewAll,
		"summary": gin.H{
			"total":   len(users),
			"present": presentCount,
			"late":    lateCount,
			"leave":   leaveCount,
			"absent":  absentCount,
		},
		"data": results,
	})
}

func GetUserMonthlyAttendance(c *gin.Context) {
	requesterID := c.MustGet("userID").(uint)
	var requester models.User
	if err := config.DB.First(&requester, requesterID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	targetIDStr := c.Param("id")
	var targetUserID uint
	if _, err := fmt.Sscanf(targetIDStr, "%d", &targetUserID); err != nil || targetUserID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	canViewAll := canViewAllAttendance(requester)
	if targetUserID != requesterID && !canViewAll {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not authorized to view attendance history of other employees"})
		return
	}

	var targetUser models.User
	if err := config.DB.First(&targetUser, targetUserID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Target user not found"})
		return
	}

	// Month param YYYY-MM
	monthStr := strings.TrimSpace(c.Query("month"))
	if monthStr == "" || len(monthStr) != 7 || !strings.Contains(monthStr, "-") {
		monthStr = time.Now().Format("2006-01")
	}

	targetTime, err := time.Parse("2006-01", monthStr)
	if err != nil {
		monthStr = time.Now().Format("2006-01")
		targetTime, _ = time.Parse("2006-01", monthStr)
	}

	year := targetTime.Year()
	month := targetTime.Month()

	startDate := fmt.Sprintf("%04d-%02d-01", year, int(month))
	nextMonth := targetTime.AddDate(0, 1, 0)
	lastDayOfMonth := nextMonth.AddDate(0, 0, -1).Day()
	endDate := fmt.Sprintf("%04d-%02d-%02d", year, int(month), lastDayOfMonth)

	// Fetch attendance records for this month
	var attendances []models.Attendance
	config.DB.Where("user_id = ? AND date >= ? AND date <= ?", targetUserID, startDate, endDate).Find(&attendances)
	attMap := make(map[string]models.Attendance)
	for _, a := range attendances {
		attMap[a.Date] = a
	}

	// Fetch approved leaves covering any day in this month
	var leaves []models.LeaveRequest
	config.DB.Preload("LeaveType").Where("user_id = ? AND status = 'APPROVED' AND start_date <= ? AND end_date >= ?", targetUserID, endDate, startDate).Find(&leaves)

	type DailyAttendanceRecord struct {
		Date         string     `json:"date"`
		DayName      string     `json:"day_name"`
		DayNumber    int        `json:"day_number"`
		IsWeekend    bool       `json:"is_weekend"`
		IsFuture     bool       `json:"is_future"`
		Status       string     `json:"status"` // PRESENT, LATE, LEAVE, ABSENT, WEEKEND, FUTURE
		CheckInTime  *time.Time `json:"check_in_time"`
		CheckOutTime *time.Time `json:"check_out_time"`
		Duration     string     `json:"duration"` // e.g. "8h 45m" or "-"
		Location     string     `json:"location"`
		Notes        string     `json:"notes"`
	}

	todayStr := time.Now().Format("2006-01-02")
	var days []DailyAttendanceRecord

	presentCount := 0
	lateCount := 0
	leaveCount := 0
	absentCount := 0
	totalWorkMinutes := 0

	for day := 1; day <= lastDayOfMonth; day++ {
		date := fmt.Sprintf("%04d-%02d-%02d", year, int(month), day)
		dateTime, _ := time.Parse("2006-01-02", date)
		isWeekend := dateTime.Weekday() == time.Saturday || dateTime.Weekday() == time.Sunday
		isFuture := date > todayStr

		record := DailyAttendanceRecord{
			Date:      date,
			DayName:   dateTime.Weekday().String(),
			DayNumber: day,
			IsWeekend: isWeekend,
			IsFuture:  isFuture,
		}

		if att, exists := attMap[date]; exists {
			record.Status = strings.ToUpper(att.Status)
			if record.Status == "" {
				record.Status = "PRESENT"
			}
			record.CheckInTime = att.CheckInTime
			record.CheckOutTime = att.CheckOutTime
			record.Location = att.CheckInAddress
			record.Notes = att.CheckInAddress

			// Calculate work duration if both in and out exist
			if att.CheckInTime != nil && att.CheckOutTime != nil {
				dur := att.CheckOutTime.Sub(*att.CheckInTime)
				if dur > 0 {
					totalMins := int(dur.Minutes())
					totalWorkMinutes += totalMins
					record.Duration = fmt.Sprintf("%dh %02dm", totalMins/60, totalMins%60)
				} else {
					record.Duration = "-"
				}
			} else {
				record.Duration = "-"
			}

			if record.Status == "LATE" {
				lateCount++
			} else {
				presentCount++
			}
		} else {
			var leaveFound *models.LeaveRequest
			for _, l := range leaves {
				if l.StartDate <= date && l.EndDate >= date {
					leaveFound = &l
					break
				}
			}

			if leaveFound != nil {
				record.Status = "LEAVE"
				typeName := "Leave"
				if leaveFound.LeaveType != nil && leaveFound.LeaveType.Name != "" {
					typeName = leaveFound.LeaveType.Name
				}
				record.Location = fmt.Sprintf("On %s", typeName)
				record.Notes = leaveFound.Reason
				record.Duration = "-"
				if !isWeekend {
					leaveCount++
				}
			} else if isWeekend {
				record.Status = "WEEKEND"
				record.Location = "Weekend Off"
				record.Duration = "-"
			} else if isFuture {
				record.Status = "FUTURE"
				record.Location = "-"
				record.Duration = "-"
			} else {
				record.Status = "ABSENT"
				record.Location = "-"
				record.Notes = "Did not check in"
				record.Duration = "-"
				absentCount++
			}
		}

		days = append(days, record)
	}

	workHoursStr := fmt.Sprintf("%dh %02dm", totalWorkMinutes/60, totalWorkMinutes%60)

	c.JSON(http.StatusOK, gin.H{
		"user": gin.H{
			"id":         targetUser.ID,
			"name":       targetUser.Name,
			"nip":        targetUser.NIP,
			"email":      targetUser.Email,
			"department": targetUser.Department,
			"role":       targetUser.Role,
			"avatar_url": targetUser.AvatarURL,
		},
		"month": monthStr,
		"summary": gin.H{
			"present":            presentCount,
			"late":               lateCount,
			"leave":              leaveCount,
			"absent":             absentCount,
			"total_present":      presentCount + lateCount,
			"total_work_minutes": totalWorkMinutes,
			"work_hours_str":     workHoursStr,
		},
		"days": days,
	})
}
