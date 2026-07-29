package main

import (
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/controllers"
	"github.com/tmmin-fid/fid-attendance-system/backend/middleware"
)

func main() {
	// Initialize Database
	config.InitDB()

	r := gin.Default()

	// Configure CORS
	corsConfig := cors.DefaultConfig()
	corsConfig.AllowAllOrigins = true
	corsConfig.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}
	r.Use(cors.New(corsConfig))

	// Health Check
	r.GET("/api/v1/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "app": "FID Attendance API", "version": "1.0.0"})
	})

	// Public Routes
	api := r.Group("/api/v1")
	{
		api.POST("/auth/login", middleware.AuditLogMiddleware("LOGIN"), controllers.Login)
	}

	// Protected Routes
	protected := api.Group("")
	protected.Use(middleware.AuthMiddleware())
	{
		// Profile & Directory Endpoints
		protected.GET("/auth/me", controllers.GetMe)
		protected.GET("/users", controllers.GetAllUsers)
		protected.PUT("/profile", middleware.AuditLogMiddleware("UPDATE_PROFILE"), controllers.UpdateProfile)

		// Attendance Mobile Endpoints
		protected.GET("/attendance/today", controllers.GetTodayStatus)
		protected.POST("/attendance/check-in", middleware.AuditLogMiddleware("CHECK_IN"), controllers.CheckIn)
		protected.POST("/attendance/check-out", middleware.AuditLogMiddleware("CHECK_OUT"), controllers.CheckOut)
		protected.GET("/attendance/history", controllers.GetAttendanceHistory)
		protected.POST("/attendance/correction", middleware.AuditLogMiddleware("REQUEST_CORRECTION"), controllers.RequestCorrection)
		protected.GET("/attendance/correction/history", controllers.GetCorrectionHistory)

		// Leave Request Endpoints
		protected.GET("/leave/types", controllers.GetLeaveTypes)
		protected.POST("/leave/request", middleware.AuditLogMiddleware("SUBMIT_LEAVE"), controllers.SubmitLeave)
		protected.GET("/leave/history", controllers.GetLeaveHistory)

		// Real Approval & Notification Endpoints
		protected.GET("/approval/pending", controllers.GetPendingApprovals)
		protected.POST("/approval/process", middleware.AuditLogMiddleware("PROCESS_APPROVAL"), controllers.ProcessApproval)
		protected.GET("/notifications", controllers.GetNotifications)
		protected.PUT("/notifications/read/:id", controllers.MarkNotificationRead)
		protected.PUT("/notifications/read-all", controllers.MarkAllNotificationsRead)
	}

	// Super Admin Routes
	admin := protected.Group("/admin")
	admin.Use(middleware.RequireRole("SUPER_ADMIN"))
	{
		admin.GET("/users", controllers.GetAllUsers)
		admin.POST("/users", middleware.AuditLogMiddleware("CREATE_USER"), controllers.CreateUser)
		admin.PUT("/users/:id", middleware.AuditLogMiddleware("UPDATE_USER"), controllers.UpdateUser)
		admin.DELETE("/users/:id", middleware.AuditLogMiddleware("DELETE_USER"), controllers.DeleteUser)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port :%s...", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
