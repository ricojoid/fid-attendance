package controllers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"golang.org/x/crypto/bcrypt"
)

type CreateUserRequest struct {
	NIP          string `json:"nip" binding:"required"`
	Name         string `json:"name" binding:"required"`
	Email        string `json:"email" binding:"required,email"`
	Password     string `json:"password" binding:"required"`
	Role         string `json:"role"` // SUPER_ADMIN, EMPLOYEE
	Department   string `json:"department"`
	BirthDate    string `json:"birth_date"`
	ApproverName string `json:"approver_name"`
	AvatarURL    string `json:"avatar_url"`
}

type UpdateUserRequest struct {
	NIP          string `json:"nip"`
	Name         string `json:"name"`
	Email        string `json:"email"`
	Password     string `json:"password"`
	Role         string `json:"role"`
	Department   string `json:"department"`
	BirthDate    string `json:"birth_date"`
	ApproverName string `json:"approver_name"`
	AvatarURL    string `json:"avatar_url"`
}

func GetAllUsers(c *gin.Context) {
	var users []models.User
	query := config.DB.Order("id desc")

	if search := c.Query("search"); search != "" {
		query = query.Where("name LIKE ? OR nip LIKE ? OR email LIKE ?", "%"+search+"%", "%"+search+"%", "%"+search+"%")
	}

	if dept := c.Query("department"); dept != "" && dept != "ALL" {
		query = query.Where("LOWER(department) = LOWER(?)", dept)
	}

	if err := query.Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": users, "master_departments": models.MasterDepartments})
}

func CreateUser(c *gin.Context) {
	var req CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Role == "" {
		req.Role = "EMPLOYEE"
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	user := models.User{
		NIP:          req.NIP,
		Name:         req.Name,
		Email:        req.Email,
		PasswordHash: string(hashed),
		Role:         req.Role,
		Department:   req.Department,
		BirthDate:    req.BirthDate,
		ApproverName: req.ApproverName,
	}

	if err := config.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to create user (NIP/Email may already exist)"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "User created successfully", "data": user})
}

func UpdateUser(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var req UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := config.DB.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if req.NIP != "" {
		user.NIP = req.NIP
	}
	if req.Name != "" {
		user.Name = req.Name
	}
	if req.Email != "" {
		user.Email = req.Email
	}
	if req.Role != "" {
		user.Role = req.Role
	}
	if req.Department != "" {
		user.Department = req.Department
	}
	if req.BirthDate != "" {
		user.BirthDate = req.BirthDate
	}
	if req.ApproverName != "" {
		user.ApproverName = req.ApproverName
	}
	if req.AvatarURL != "" {
		user.AvatarURL = req.AvatarURL
	}
	if req.Password != "" {
		hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err == nil {
			user.PasswordHash = string(hashed)
		}
	}

	if err := config.DB.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User updated successfully", "data": user})
}

func DeleteUser(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	if err := config.DB.Delete(&models.User{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User deleted successfully"})
}
