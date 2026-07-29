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

	// 1. Notification for submitter user
	notifSubmitter := models.Notification{
		UserID:    userID,
		Title:     fmt.Sprintf("%s Submitted: PENDING", leaveTypeName),
		Message:   fmt.Sprintf("Your %s for %s to %s has been submitted successfully.", leaveTypeName, req.StartDate, req.EndDate),
		Type:      "LEAVE",
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
				Title:     fmt.Sprintf("Approval Request: %s", leaveTypeName),
				Message:   fmt.Sprintf("%s has submitted a %s for %s to %s needing your approval.", user.Name, leaveTypeName, req.StartDate, req.EndDate),
				Type:      "LEAVE",
				Status:    "PENDING",
				CreatedAt: time.Now(),
			}
			config.DB.Create(&notifApprover)
		}
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Leave request submitted successfully", "data": leaveReq})
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
