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

	tokenString, expiresAt, err := issueToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Login successful",
		"token":      tokenString,
		"expires_at": expiresAt,
		"user":       user,
	})
}

// SessionIdleTimeout is a sliding window: every time the app is opened the
// client calls /auth/refresh and gets a fresh token valid for another 30 days.
// A user is logged out only after 30 days without opening the app.
const SessionIdleTimeout = 30 * 24 * time.Hour

func jwtSecret() []byte {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "super-secret-attendance-key-2026"
	}
	return []byte(secret)
}

func issueToken(user models.User) (string, time.Time, error) {
	now := time.Now()
	exp := now.Add(SessionIdleTimeout)
	claims := jwt.MapClaims{
		"user_id": user.ID,
		"nip":     user.NIP,
		"email":   user.Email,
		"role":    user.Role,
		"iat":     now.Unix(),
		"exp":     exp.Unix(),
	}
	s, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(jwtSecret())
	return s, exp, err
}

// RefreshToken (POST /auth/refresh) slides the 30-day session forward.
// Requires a still-valid token, so an expired session cannot be revived.
func RefreshToken(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	var user models.User
	if err := config.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User no longer exists"})
		return
	}
	tokenString, expiresAt, err := issueToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to refresh session"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": tokenString, "expires_at": expiresAt, "user": user})
}

func GetMe(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var user models.User
	if err := config.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user, "approver": approverSummary(resolveApproverFor(&user))})
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
