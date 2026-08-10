package controllers

import (
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"golang.org/x/crypto/bcrypt"
)

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type UpdateProfileRequest struct {
	Name         string `json:"name"`
	Department   string `json:"department"`
	BirthDate    string `json:"birth_date"`
	Password     string `json:"password"`
	ApproverName string `json:"approver_name"`
	AvatarURL    string `json:"avatar_url"`
}

func Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email and password are required"})
		return
	}

	var user models.User
	if err := config.DB.Where("email = ?", req.Email).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid email or password"})
		return
	}

	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "super-secret-attendance-key-2026"
	}

	claims := jwt.MapClaims{
		"user_id": user.ID,
		"nip":     user.NIP,
		"email":   user.Email,
		"role":    user.Role,
		"exp":     time.Now().AddDate(100, 0, 0).Unix(), // Permanent token until logout (100 years)
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Login successful",
		"token":   tokenString,
		"user":    user,
	})
}

func GetMe(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var user models.User
	if err := config.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}

func UpdateProfile(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	if err := config.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if req.Name != "" {
		user.Name = req.Name
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
		"user":    user,
	})
}
