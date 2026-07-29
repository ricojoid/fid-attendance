package config

import (
	"fmt"
	"log"
	"os"

	"github.com/glebarez/sqlite"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func getEnvOrDefault(key, defaultValue string) string {
	val := os.Getenv(key)
	if val == "" {
		return defaultValue
	}
	return val
}

func InitDB() *gorm.DB {
	dbDriver := getEnvOrDefault("DB_DRIVER", "postgres")
	var dialector gorm.Dialector

	if dbDriver == "postgres" {
		host := getEnvOrDefault("DB_HOST", "localhost")
		port := getEnvOrDefault("DB_PORT", "5432")
		user := getEnvOrDefault("DB_USER", "postgres")
		password := os.Getenv("DB_PASSWORD")
		dbname := getEnvOrDefault("DB_NAME", "fid_attendance")
		sslmode := getEnvOrDefault("DB_SSLMODE", "disable")

		dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
			host, user, password, dbname, port, sslmode)
		log.Printf("Connecting to PostgreSQL database: host=%s port=%s user=%s dbname=%s...", host, port, user, dbname)
		dialector = postgres.Open(dsn)
	} else {
		dbName := getEnvOrDefault("DB_NAME", "attendance.db")
		log.Printf("Connecting to SQLite database: %s...", dbName)
		dialector = sqlite.Open(dbName)
	}

	db, err := gorm.Open(dialector, &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	log.Println("Running AutoMigrations...")
	err = db.AutoMigrate(
		&models.User{},
		&models.LeaveType{},
		&models.Attendance{},
		&models.LeaveRequest{},
		&models.AttendanceCorrection{},
		&models.Notification{},
		&models.LogHeader{},
		&models.LogDetail{},
	)
	if err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	DB = db
	seedInitialData(db)
	return db
}

func seedInitialData(db *gorm.DB) {
	var count int64
	db.Model(&models.User{}).Count(&count)
	if count <= 2 {
		log.Println("Seeding initial users & approver mappings...")
		adminPass, _ := bcrypt.GenerateFromPassword([]byte("Admin123!"), bcrypt.DefaultCost)
		empPass, _ := bcrypt.GenerateFromPassword([]byte("User123!"), bcrypt.DefaultCost)

		users := []models.User{
			{
				NIP:          "ADM001",
				Name:         "Super Administrator",
				Email:        "admin@office.com",
				PasswordHash: string(adminPass),
				Role:         "SUPER_ADMIN",
				Department:   "IT & Systems",
			},
			{
				NIP:          "DHD001",
				Name:         "Dina",
				Email:        "dina@office.com",
				PasswordHash: string(empPass),
				Role:         "DEPARTMENT_HEAD",
				Department:   "Engineering & IT",
			},
			{
				NIP:          "EMP701",
				Name:         "Rico",
				Email:        "rico@office.com",
				PasswordHash: string(empPass),
				Role:         "EMPLOYEE",
				Department:   "Engineering & IT",
				ApproverName: "Dina",
			},
			{
				NIP:          "EMP001",
				Name:         "Budi Santoso",
				Email:        "employee@office.com",
				PasswordHash: string(empPass),
				Role:         "EMPLOYEE",
				Department:   "Human Resources",
				ApproverName: "Dina",
			},
		}

		for _, u := range users {
			var existing models.User
			if err := db.Where("email = ?", u.Email).First(&existing).Error; err != nil {
				db.Create(&u)
			}
		}
	}

	var leaveTypeCount int64
	db.Model(&models.LeaveType{}).Count(&leaveTypeCount)
	if leaveTypeCount == 0 {
		log.Println("Seeding leave types...")
		leaveTypes := []models.LeaveType{
			{Code: "ANNUAL", Name: "Cuti Tahunan", DefaultQuota: 12},
			{Code: "SICK", Name: "Cuti Sakit", DefaultQuota: 10},
			{Code: "SPECIAL", Name: "Cuti Khusus", DefaultQuota: 3},
		}
		for _, lt := range leaveTypes {
			db.Create(&lt)
		}
	}
}
