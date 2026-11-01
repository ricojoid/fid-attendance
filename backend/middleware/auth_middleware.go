package middleware

import (
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		// Browsers' EventSource cannot send headers, so the live-events stream
		// (and only it) may pass the token as a query parameter.
		if authHeader == "" && strings.HasSuffix(c.Request.URL.Path, "/events") {
			if t := c.Query("access_token"); t != "" {
				authHeader = "Bearer " + t
			}
		}
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization token required"})
			c.Abort()
			return
		}

		tokenString := strings.Replace(authHeader, "Bearer ", "", 1)
		secret := os.Getenv("JWT_SECRET")
		if secret == "" {
			secret = "super-secret-attendance-key-2026"
		}

		if strings.TrimSpace(tokenString) == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization token required"})
			c.Abort()
			return
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(secret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
			return
		}

		userIDFloat, ok := claims["user_id"].(float64)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID in token"})
			c.Abort()
			return
		}

		userID := uint(userIDFloat)
		role, _ := claims["role"].(string)

		c.Set("userID", userID)
		c.Set("userRole", role)

		c.Next()
	}
}

func RequireRole(requiredRole string) gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("userRole")
		if !exists || role.(string) != requiredRole {
			c.JSON(http.StatusForbidden, gin.H{"error": "Access denied: insufficient permission"})
			c.Abort()
			return
		}
		c.Next()
	}
}

func AuditLogMiddleware(actionName string) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if c.Writer.Status() >= 200 && c.Writer.Status() < 300 {
			val, exists := c.Get("userID")
			var userID uint = 0
			if exists {
				userID = val.(uint)
			}

			logH := models.LogHeader{
				UserID:    userID,
				Action:    actionName,
				ClientIP:  c.ClientIP(),
				UserAgent: c.Request.UserAgent(),
				CreatedAt: time.Now(),
			}

			// Write the audit row off the request path so it never adds latency.
			if config.DB != nil {
				go config.DB.Create(&logH)
			}
		}
	}
}
