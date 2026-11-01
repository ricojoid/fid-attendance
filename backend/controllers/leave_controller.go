package controllers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

type CreateLeaveRequest struct {
	LeaveTypeID uint   `json:"leave_type_id" binding:"required"`
	StartDate   string `json:"start_date" binding:"required"` // YYYY-MM-DD
	EndDate     string `json:"end_date" binding:"required"`   // YYYY-MM-DD
	Reason      string `json:"reason" binding:"required"`
}

func GetLeaveTypes(c *gin.Context) {
	var types []models.LeaveType
	if err := config.DB.Find(&types).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch leave types"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": types})
}

func SubmitLeave(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req CreateLeaveRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	start, errS := time.Parse("2006-01-02", req.StartDate)
	end, errE := time.Parse("2006-01-02", req.EndDate)
	if errS != nil || errE != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Dates must use the YYYY-MM-DD format"})
		return
	}
	if end.Before(start) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "End date cannot be before start date"})
		return
	}
	var overlap int64
	config.DB.Model(&models.LeaveRequest{}).
		Where("user_id = ? AND status IN ? AND start_date <= ? AND end_date >= ?", userID, []string{"PENDING", "APPROVED"}, req.EndDate, req.StartDate).
		Count(&overlap)
	if overlap > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "You already have a pending or approved leave overlapping these dates"})
		return
	}

	leaveReq := models.LeaveRequest{
		UserID:      userID,
		LeaveTypeID: req.LeaveTypeID,
		StartDate:   req.StartDate,
		EndDate:     req.EndDate,
		Reason:      req.Reason,
		Status:      "PENDING",
	}

	if err := config.DB.Create(&leaveReq).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit leave request"})
		return
	}

	config.DB.Preload("LeaveType").First(&leaveReq, leaveReq.ID)

	var user models.User
	config.DB.First(&user, userID)

	leaveTypeName := "Leave Request"
	if leaveReq.LeaveType != nil {
		leaveTypeName = leaveReq.LeaveType.Name
	}

	approverUser := resolveApproverFor(&user)
	sentTo := ""
	if approverUser != nil {
		sentTo = fmt.Sprintf(" It has been sent to %s for approval.", approverUser.Name)
	}

	// 1. Notification for submitter user
	notifSubmitter := models.Notification{
		UserID:    userID,
		Title:     fmt.Sprintf("%s Submitted: PENDING", leaveTypeName),
		Message:   fmt.Sprintf("Your %s for %s to %s has been submitted successfully.%s", leaveTypeName, req.StartDate, req.EndDate, sentTo),
		Type:      "LEAVE",
		Status:    "PENDING",
		CreatedAt: time.Now(),
	}
	config.DB.Create(&notifSubmitter)

	// 2. Notify whoever is responsible for approving (mapped approver or hierarchy fallback)
	if approverUser != nil {
		{
			notifApprover := models.Notification{
				UserID:    approverUser.ID,
				Title:     fmt.Sprintf("Approval Request: %s", leaveTypeName),
				Message:   fmt.Sprintf("%s has submitted a %s for %s to %s needing your approval.", user.Name, leaveTypeName, req.StartDate, req.EndDate),
				Type:      "LEAVE",
				Status:    "PENDING",
				CreatedAt: time.Now(),
			}
			config.DB.Create(&notifApprover)
		}
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Leave request submitted successfully", "data": leaveReq, "approver": approverSummary(approverUser)})
}

func GetLeaveHistory(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var list []models.LeaveRequest
	if err := config.DB.Preload("LeaveType").Where("user_id = ?", userID).Order("id desc").Find(&list).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch leave requests"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": list})
}
