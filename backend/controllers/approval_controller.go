package controllers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"gorm.io/gorm"
)

type ProcessApprovalRequest struct {
	Type   string `json:"type" binding:"required"` // LEAVE, CORRECTION / ATTENDANCE
	ID     uint   `json:"id" binding:"required"`
	Status string `json:"status" binding:"required"` // APPROVED, REJECTED
}

func approverSummary(u *models.User) gin.H {
	if u == nil {
		return nil
	}
	return gin.H{"id": u.ID, "name": u.Name, "role": u.Role, "department": u.Department}
}

// GetPendingApprovals returns the pending requests this user is responsible for
// (see approver.go for the routing rules). SUPER_ADMIN sees everything.
func GetPendingApprovals(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	dir := loadApproverDirectory()
	me := dir.byID[userID]
	if me == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	var leaves []models.LeaveRequest
	config.DB.Preload("User").Preload("LeaveType").Where("status = ?", "PENDING").Order("id desc").Find(&leaves)

	var corrections []models.AttendanceCorrection
	config.DB.Preload("User").Where("status = ?", "PENDING").Order("id desc").Find(&corrections)

	results := []gin.H{}

	for _, l := range leaves {
		if l.User == nil || !dir.CanProcess(me, l.User) {
			continue
		}
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
			"start_date":       l.StartDate,
			"end_date":         l.EndDate,
			"reason":           l.Reason,
			"status":           l.Status,
			"approver":         approverSummary(dir.Resolve(l.User)),
			"created_at":       l.CreatedAt.Format("2006-01-02 15:04"),
		})
	}

	for _, cr := range corrections {
		if cr.User == nil || !dir.CanProcess(me, cr.User) {
			continue
		}
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
			"approver":         approverSummary(dir.Resolve(cr.User)),
			"created_at":       cr.CreatedAt.Format("2006-01-02 15:04"),
		})
	}

	c.JSON(http.StatusOK, gin.H{"data": results})
}

// GetMyApprover tells the client who will receive this user's requests,
// so the UI can show "This request will be sent to …" before submitting.
func GetMyApprover(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	dir := loadApproverDirectory()
	me := dir.byID[userID]
	if me == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"approver": approverSummary(dir.Resolve(me))})
}

func isLate(t *time.Time) bool {
	return t != nil && (t.Hour() > 8 || (t.Hour() == 8 && t.Minute() > 30))
}

// ProcessApproval approves/rejects a request and notifies the applicant.
func ProcessApproval(c *gin.Context) {
	approverID := c.MustGet("userID").(uint)

	var req ProcessApprovalRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	reqTypeUpper := strings.ToUpper(strings.TrimSpace(req.Type))
	newStatus := strings.ToUpper(strings.TrimSpace(req.Status))
	if newStatus != "APPROVED" && newStatus != "REJECTED" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Status must be APPROVED or REJECTED"})
		return
	}

	dir := loadApproverDirectory()
	approver := dir.byID[approverID]
	if approver == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	var applicantID uint
	var reqTitle, reqDetails string
	errAlreadyProcessed := fmt.Errorf("already processed")

	if reqTypeUpper == "LEAVE" {
		var leave models.LeaveRequest
		if err := config.DB.Preload("User").First(&leave, req.ID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Leave request not found"})
			return
		}
		if !dir.CanProcess(approver, leave.User) {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not the approver for this request"})
			return
		}
		// Conditional update: only a PENDING request can change state. This also
		// makes double-clicks / two approvers racing each other safe.
		res := config.DB.Model(&models.LeaveRequest{}).
			Where("id = ? AND status = ?", leave.ID, "PENDING").
			Update("status", newStatus)
		if res.Error != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update leave request"})
			return
		}
		if res.RowsAffected == 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "This request has already been processed"})
			return
		}

		applicantID = leave.UserID
		reqTitle = "Leave Request Status"
		reqDetails = fmt.Sprintf("Your leave request for %s to %s has been %s by %s.", leave.StartDate, leave.EndDate, newStatus, approver.Name)
	} else {
		var corr models.AttendanceCorrection
		if err := config.DB.Preload("User").First(&corr, req.ID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Attendance correction request not found"})
			return
		}
		if !dir.CanProcess(approver, corr.User) {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not the approver for this request"})
			return
		}

		err := config.DB.Transaction(func(tx *gorm.DB) error {
			res := tx.Model(&models.AttendanceCorrection{}).
				Where("id = ? AND status = ?", corr.ID, "PENDING").
				Update("status", newStatus)
			if res.Error != nil {
				return res.Error
			}
			if res.RowsAffected == 0 {
				return errAlreadyProcessed
			}
			if newStatus != "APPROVED" {
				return nil
			}

			// Persist the approved correction into TB_R_ATTENDANCE.
			var att models.Attendance
			if err := tx.Where("user_id = ? AND date = ?", corr.UserID, corr.AttendanceDate).First(&att).Error; err != nil {
				status := "PRESENT"
				if isLate(corr.CorrectedCheckIn) {
					status = "LATE"
				}
				att = models.Attendance{
					UserID:         corr.UserID,
					Date:           corr.AttendanceDate,
					CheckInTime:    corr.CorrectedCheckIn,
					CheckOutTime:   corr.CorrectedCheckOut,
					CheckInAddress: "Approved Correction: " + corr.Reason,
					Status:         status,
					Source:         "CORRECTION", // not a live check-in → excluded from streaks
					IsCorrected:    true,
				}
				return tx.Create(&att).Error
			}
			if corr.CorrectedCheckIn != nil {
				att.CheckInTime = corr.CorrectedCheckIn
				if isLate(corr.CorrectedCheckIn) {
					att.Status = "LATE"
				} else {
					att.Status = "PRESENT"
				}
			}
			if corr.CorrectedCheckOut != nil {
				att.CheckOutTime = corr.CorrectedCheckOut
			}
			att.CheckInAddress = "Approved Correction: " + corr.Reason
			att.IsCorrected = true
			return tx.Save(&att).Error
		})
		if err == errAlreadyProcessed {
			c.JSON(http.StatusConflict, gin.H{"error": "This request has already been processed"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process correction request"})
			return
		}
		if newStatus == "APPROVED" {
			syncBadgesAsync(corr.UserID)
		}

		applicantID = corr.UserID
		reqTitle = "Attendance Correction Status"
		reqDetails = fmt.Sprintf("Your attendance correction request for %s has been %s by %s.", corr.AttendanceDate, newStatus, approver.Name)
	}

	notification := models.Notification{
		UserID:    applicantID,
		Title:     fmt.Sprintf("%s: %s", reqTitle, newStatus),
		Message:   reqDetails,
		Type:      reqTypeUpper,
		Status:    newStatus,
		CreatedAt: time.Now(),
	}
	config.DB.Create(&notification)

	c.JSON(http.StatusOK, gin.H{
		"message":      fmt.Sprintf("Request successfully %s", newStatus),
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
