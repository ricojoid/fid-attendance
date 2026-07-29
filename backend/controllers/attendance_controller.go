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

func RequestCorrection(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req CorrectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var correctedIn, correctedOut *time.Time
	if req.CorrectedCheckIn != "" {
		t, err := time.Parse(time.RFC3339, req.CorrectedCheckIn)
		if err == nil {
			correctedIn = &t
		} else {
			// Fallback parse simple time HH:MM
			t2, _ := time.Parse("2006-01-02 15:04", req.AttendanceDate+" "+req.CorrectedCheckIn)
			correctedIn = &t2
		}
	}
	if req.CorrectedCheckOut != "" {
		t, err := time.Parse(time.RFC3339, req.CorrectedCheckOut)
		if err == nil {
			correctedOut = &t
		} else {
			t2, _ := time.Parse("2006-01-02 15:04", req.AttendanceDate+" "+req.CorrectedCheckOut)
			correctedOut = &t2
		}
	}

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
