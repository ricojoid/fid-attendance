package controllers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

// GetAnnouncements returns active announcements (or all for admin query)
func GetAnnouncements(c *gin.Context) {
	var announcements []models.Announcement
	query := config.DB.Preload("Author")

	// If non-admin user or requested active only
	showAll := c.Query("all") == "true"
	userRole, _ := c.Get("user_role")

	if !showAll || userRole != "SUPER_ADMIN" {
		query = query.Where("is_active = ?", true)
	}

	if err := query.Order("created_at DESC").Find(&announcements).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch announcements"})
		return
	}

	c.JSON(http.StatusOK, announcements)
}

// CreateAnnouncement (Super Admin only)
func CreateAnnouncement(c *gin.Context) {
	userIDVal, _ := c.Get("user_id")
	authorID := userIDVal.(uint)

	var req struct {
		Title    string `json:"title" binding:"required"`
		Content  string `json:"content" binding:"required"`
		Category string `json:"category"`
		IsActive *bool  `json:"is_active"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payload: title and content are required"})
		return
	}

	category := req.Category
	if category == "" {
		category = "GENERAL"
	}

	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	announcement := models.Announcement{
		Title:    req.Title,
		Content:  req.Content,
		Category: category,
		AuthorID: authorID,
		IsActive: isActive,
	}

	if err := config.DB.Create(&announcement).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create announcement"})
		return
	}

	config.DB.Preload("Author").First(&announcement, announcement.ID)
	c.JSON(http.StatusCreated, announcement)
}

// UpdateAnnouncement (Super Admin only)
func UpdateAnnouncement(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid announcement ID"})
		return
	}

	var announcement models.Announcement
	if err := config.DB.First(&announcement, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Announcement not found"})
		return
	}

	var req struct {
		Title    string `json:"title"`
		Content  string `json:"content"`
		Category string `json:"category"`
		IsActive *bool  `json:"is_active"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request payload"})
		return
	}

	if req.Title != "" {
		announcement.Title = req.Title
	}
	if req.Content != "" {
		announcement.Content = req.Content
	}
	if req.Category != "" {
		announcement.Category = req.Category
	}
	if req.IsActive != nil {
		announcement.IsActive = *req.IsActive
	}

	if err := config.DB.Save(&announcement).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update announcement"})
		return
	}

	config.DB.Preload("Author").First(&announcement, announcement.ID)
	c.JSON(http.StatusOK, announcement)
}

// DeleteAnnouncement (Super Admin only)
func DeleteAnnouncement(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid announcement ID"})
		return
	}

	if err := config.DB.Delete(&models.Announcement{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete announcement"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Announcement deleted successfully"})
}
