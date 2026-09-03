package config

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/glebarez/sqlite"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func loadEnv() {
	envFiles := []string{".env", "backend/.env", "../backend/.env"}
	for _, envFile := range envFiles {
		file, err := os.Open(envFile)
		if err != nil {
			continue
		}
		defer file.Close()
		scanner := bufio.NewScanner(file)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				k := strings.TrimSpace(parts[0])
				v := strings.TrimSpace(parts[1])
				v = strings.Trim(v, `"'`)
				if os.Getenv(k) == "" {
					_ = os.Setenv(k, v)
				}
			}
		}
		break
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	val := os.Getenv(key)
	if val == "" {
		return defaultValue
	}
	return val
}

func InitDB() *gorm.DB {
	loadEnv()

	dbDriver := getEnvOrDefault("DB_DRIVER", "postgres")
	var dialector gorm.Dialector

	if dbDriver == "postgres" {
		host := getEnvOrDefault("DB_HOST", "localhost")
		port := getEnvOrDefault("DB_PORT", "5432")
		user := getEnvOrDefault("DB_USER", "postgres")
		password := getEnvOrDefault("DB_PASSWORD", "admin123")
		dbname := getEnvOrDefault("DB_NAME", "postgres")
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
		&models.Announcement{},
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
	log.Println("Verifying / Seeding initial hierarchy users...")
	adminPass, _ := bcrypt.GenerateFromPassword([]byte("Admin123!"), bcrypt.DefaultCost)
	empPass, _ := bcrypt.GenerateFromPassword([]byte("User123!"), bcrypt.DefaultCost)

	users := []models.User{
		{
			NIP:          "ADM001",
			Name:         "Super Administrator",
			Email:        "admin@office.com",
			PasswordHash: string(adminPass),
			Role:         models.RoleSuperAdmin,
			Department:   "Human Resource",
		},
		{
			NIP:          "CHD001",
			Name:         "Country Head",
			Email:        "countryhead@office.com",
			PasswordHash: string(adminPass),
			Role:         models.RoleCountryHead,
			Department:   "Human Resource",
		},
		{
			NIP:          "MGR001",
			Name:         "HR Manager",
			Email:        "hrmanager@office.com",
			PasswordHash: string(empPass),
			Role:         models.RoleManager,
			Department:   "Human Resource",
		},
		{
			NIP:          "MGR002",
			Name:         "Manager AppDev",
			Email:        "manager.appdev@office.com",
			PasswordHash: string(empPass),
			Role:         models.RoleManager,
			Department:   "App Dev & Data AI",
		},
		{
			NIP:          "DHD001",
			Name:         "Dina",
			Email:        "dina@office.com",
			PasswordHash: string(empPass),
			Role:         models.RoleDepartmentHead,
			Department:   "App Dev & Data AI",
			ApproverName: "Manager AppDev",
		},
		{
			NIP:          "EMP701",
			Name:         "Rico",
			Email:        "rico@office.com",
			PasswordHash: string(empPass),
			Role:         models.RoleEmployee,
			Department:   "App Dev & Data AI",
			ApproverName: "Dina",
		},
		{
			NIP:          "EMP001",
			Name:         "Budi Santoso",
			Email:        "employee@office.com",
			PasswordHash: string(empPass),
			Role:         models.RoleEmployee,
			Department:   "Sales",
			ApproverName: "Dina",
		},
	}

	for _, u := range users {
		var existing models.User
		if err := db.Where("email = ?", u.Email).First(&existing).Error; err != nil {
			db.Create(&u)
		} else {
			// Update role and department if already existing
			existing.Role = u.Role
			existing.Department = u.Department
			if u.ApproverName != "" {
				existing.ApproverName = u.ApproverName
			}
			db.Save(&existing)
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

	var annCount int64
	db.Model(&models.Announcement{}).Count(&annCount)
	if annCount == 0 {
		log.Println("Seeding initial company announcements...")
		announcements := []models.Announcement{
			{
				Title:    "Sistem Absensi Online FID Resmi Beroperasi",
				Content:  "Selamat datang di Sistem Absensi Online Fujitsu FID. Seluruh karyawan dapat melakukan check-in, check-out, dan pengajuan cuti secara langsung melalui aplikasi web dan mobile.",
				Category: "IMPORTANT",
				AuthorID: 1,
				IsActive: true,
			},
			{
				Title:    "Jadwal Maintenance Server Bulanan",
				Content:  "Pemeliharaan rutin server akan dilaksanakan pada hari Sabtu pukul 22:00 WIB. Sistem mungkin tidak dapat diakses selama 30 menit.",
				Category: "MAINTENANCE",
				AuthorID: 1,
				IsActive: true,
			},
		}
		for _, a := range announcements {
			db.Create(&a)
		}
	}
}
