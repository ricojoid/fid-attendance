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

type ProcessApprovalRequest struct {
	Type   string `json:"type" binding:"required"` // LEAVE, CORRECTION
	ID     uint   `json:"id" binding:"required"`
	Status string `json:"status" binding:"required"` // APPROVED, REJECTED
}

// GetPendingApprovals returns requests where the submitter's approver maps exactly
// to the logged-in user, based on approver_name → user lookup in DB.
// SUPER_ADMIN sees all pending requests.
func GetPendingApprovals(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var currentUser models.User
	if err := config.DB.First(&currentUser, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	isSuperAdmin := strings.ToUpper(currentUser.Role) == "SUPER_ADMIN"

	// Fetch leave requests with submitter user preloaded
	var leaves []models.LeaveRequest
	config.DB.Preload("User").Preload("LeaveType").Where("status = ?", "PENDING").Order("id desc").Find(&leaves)

	// Fetch correction requests with submitter user preloaded
	var corrections []models.AttendanceCorrection
	config.DB.Preload("User").Where("status = ?", "PENDING").Order("id desc").Find(&corrections)

	var results []gin.H

	// Filter leave requests: match by looking up approver_name as exact user in DB
	for _, l := range leaves {
		if l.User == nil {
			continue
		}
		approverName := strings.TrimSpace(l.User.ApproverName)
		if approverName == "" {
			continue
		}

		// Lookup the approver user record by name (exact, case-insensitive)
		var approverUser models.User
		if err := config.DB.Where("LOWER(name) = LOWER(?)", approverName).First(&approverUser).Error; err != nil {
			// approver_name doesn't match any registered user — skip
			continue
		}

		// Show this request only to the matched approver (or Super Admin)
		if approverUser.ID == userID || isSuperAdmin {
			typeName := "Leave Request"
			if l.LeaveType != nil {
				typeName = l.LeaveType.Name
			}
			results = append(results, gin.H{
				"id":               l.ID,
				"category":         "LEAVE",
				"applicant_name":   l.User.Name,
				"applicant_id":     l.UserID,
				"applicant_avatar": l.User.AvatarURL,
				"department":       l.User.Department,
				"request_type":     typeName,
				"period":           fmt.Sprintf("%s to %s", l.StartDate, l.EndDate),
				"reason":           l.Reason,
				"status":           l.Status,
				"created_at":       l.CreatedAt.Format("2006-01-02 15:04"),
			})
		}
	}

	// Filter correction requests: same exact-match logic
	for _, cr := range corrections {
		if cr.User == nil {
			continue
		}
		approverName := strings.TrimSpace(cr.User.ApproverName)
		if approverName == "" {
			continue
		}

		var approverUser models.User
		if err := config.DB.Where("LOWER(name) = LOWER(?)", approverName).First(&approverUser).Error; err != nil {
			continue
		}

		if approverUser.ID == userID || isSuperAdmin {
			periodStr := fmt.Sprintf("Date: %s", cr.AttendanceDate)
			if cr.CorrectedCheckIn != nil && cr.CorrectedCheckOut != nil {
				periodStr = fmt.Sprintf("Date: %s (%s - %s)", cr.AttendanceDate, cr.CorrectedCheckIn.Format("15:04"), cr.CorrectedCheckOut.Format("15:04"))
			} else if cr.CorrectedCheckIn != nil {
				periodStr = fmt.Sprintf("Date: %s (In: %s)", cr.AttendanceDate, cr.CorrectedCheckIn.Format("15:04"))
			}

			results = append(results, gin.H{
				"id":               cr.ID,
				"category":         "ATTENDANCE",
				"applicant_name":   cr.User.Name,
				"applicant_id":     cr.UserID,
				"applicant_avatar": cr.User.AvatarURL,
				"department":       cr.User.Department,
				"request_type":     "Attendance Correction",
				"period":           periodStr,
				"reason":           cr.Reason,
				"status":           cr.Status,
				"created_at":       cr.CreatedAt.Format("2006-01-02 15:04"),
			})
		}
	}

	if results == nil {
		results = []gin.H{}
	}

	c.JSON(http.StatusOK, gin.H{"data": results})
}

// ProcessApproval updates DB status & inserts a Notification record for the applicant user
func ProcessApproval(c *gin.Context) {
	approverID := c.MustGet("userID").(uint)

	var approver models.User
	config.DB.First(&approver, approverID)

	var req ProcessApprovalRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	reqTypeUpper := strings.ToUpper(req.Type)
	newStatusUpper := strings.ToUpper(req.Status)

	var applicantID uint
	var reqTitle string
	var reqDetails string

	if reqTypeUpper == "LEAVE" {
		var leave models.LeaveRequest
		if err := config.DB.Preload("User").First(&leave, req.ID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Leave request not found"})
			return
		}

		// Verify the approver is authorized to process this request
		if leave.User != nil {
			mappedApprover := strings.TrimSpace(strings.ToLower(leave.User.ApproverName))
			myName := strings.TrimSpace(strings.ToLower(approver.Name))
			isSuperAdmin := strings.ToUpper(approver.Role) == "SUPER_ADMIN"
			if !isSuperAdmin && !strings.Contains(mappedApprover, myName) {
				c.JSON(http.StatusForbidden, gin.H{"error": "You are not authorized to approve this request"})
				return
			}
		}

		leave.Status = newStatusUpper
		config.DB.Save(&leave)

		applicantID = leave.UserID
		reqTitle = "Leave Request Status"
		reqDetails = fmt.Sprintf("Your leave request for %s to %s has been %s by %s.", leave.StartDate, leave.EndDate, newStatusUpper, approver.Name)
	} else {
		var corr models.AttendanceCorrection
		if err := config.DB.Preload("User").First(&corr, req.ID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Attendance correction request not found"})
			return
		}

		// Verify the approver is authorized to process this request
		if corr.User != nil {
			mappedApprover := strings.TrimSpace(strings.ToLower(corr.User.ApproverName))
			myName := strings.TrimSpace(strings.ToLower(approver.Name))
			isSuperAdmin := strings.ToUpper(approver.Role) == "SUPER_ADMIN"
			if !isSuperAdmin && !strings.Contains(mappedApprover, myName) {
				c.JSON(http.StatusForbidden, gin.H{"error": "You are not authorized to approve this request"})
				return
			}
		}

		corr.Status = newStatusUpper
		config.DB.Save(&corr)

		applicantID = corr.UserID
		reqTitle = "Attendance Correction Status"
		reqDetails = fmt.Sprintf("Your attendance correction request for %s has been %s by %s.", corr.AttendanceDate, newStatusUpper, approver.Name)

		if newStatusUpper == "APPROVED" {
			// Persist approved correction into TB_R_ATTENDANCE table
			var att models.Attendance
			err := config.DB.Where("user_id = ? AND date = ?", corr.UserID, corr.AttendanceDate).First(&att).Error
			if err != nil {
				status := "PRESENT"
				if corr.CorrectedCheckIn != nil && (corr.CorrectedCheckIn.Hour() > 8 || (corr.CorrectedCheckIn.Hour() == 8 && corr.CorrectedCheckIn.Minute() > 30)) {
					status = "LATE"
				}

				att = models.Attendance{
					UserID:         corr.UserID,
					Date:           corr.AttendanceDate,
					CheckInTime:    corr.CorrectedCheckIn,
					CheckOutTime:   corr.CorrectedCheckOut,
					CheckInAddress: "Approved Correction: " + corr.Reason,
					Status:         status,
				}
				config.DB.Create(&att)
			} else {
				if corr.CorrectedCheckIn != nil {
					att.CheckInTime = corr.CorrectedCheckIn
					if corr.CorrectedCheckIn.Hour() > 8 || (corr.CorrectedCheckIn.Hour() == 8 && corr.CorrectedCheckIn.Minute() > 30) {
						att.Status = "LATE"
					} else {
						att.Status = "PRESENT"
					}
				}
				if corr.CorrectedCheckOut != nil {
					att.CheckOutTime = corr.CorrectedCheckOut
				}
				att.CheckInAddress = "Approved Correction: " + corr.Reason
				config.DB.Save(&att)
			}
		}
	}

	// Insert Notification into DB for the Applicant User
	notification := models.Notification{
		UserID:    applicantID,
		Title:     fmt.Sprintf("%s: %s", reqTitle, newStatusUpper),
		Message:   reqDetails,
		Type:      reqTypeUpper,
		Status:    newStatusUpper,
		CreatedAt: time.Now(),
	}
	config.DB.Create(&notification)

	c.JSON(http.StatusOK, gin.H{
		"message":      fmt.Sprintf("Request successfully %s", newStatusUpper),
		"notification": notification,
	})
}

// GetNotifications returns DB notification list for the logged-in user
func GetNotifications(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var notifs []models.Notification
	if err := config.DB.Where("user_id = ?", userID).Order("id desc").Find(&notifs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch notifications"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": notifs})
}

// MarkNotificationRead marks a single notification as READ in DB
func MarkNotificationRead(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	notifID := c.Param("id")

	if err := config.DB.Model(&models.Notification{}).Where("id = ? AND user_id = ?", notifID, userID).Updates(map[string]interface{}{
		"status":  "READ",
		"is_read": true,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update notification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification marked as read"})
}

// MarkAllNotificationsRead marks all notifications as READ for the logged-in user
func MarkAllNotificationsRead(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	if err := config.DB.Model(&models.Notification{}).Where("user_id = ?", userID).Updates(map[string]interface{}{
		"status":  "READ",
		"is_read": true,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark all notifications as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "All notifications marked as read"})
}
