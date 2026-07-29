package models

import (
	"time"
)

// Master Tables
type User struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	NIP          string    `gorm:"size:50;uniqueIndex;not null" json:"nip"`
	Name         string    `gorm:"size:100;not null" json:"name"`
	Email        string    `gorm:"size:100;uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"size:255;not null" json:"-"`
	Role         string    `gorm:"size:50;default:'EMPLOYEE'" json:"role"` // SUPER_ADMIN, COUNTRY_HEAD, MANAGER, DEPARTMENT_HEAD, EMPLOYEE
	Department   string    `gorm:"size:100" json:"department"`
	AvatarURL    string    `gorm:"size:255" json:"avatar_url"`
	ApproverName string    `gorm:"size:100" json:"approver_name"`
	BirthDate    string    `gorm:"size:20" json:"birth_date"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (User) TableName() string {
	return "TB_M_USER"
}

type LeaveType struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Code         string    `gorm:"size:20;uniqueIndex;not null" json:"code"`
	Name         string    `gorm:"size:100;not null" json:"name"`
	DefaultQuota int       `gorm:"default:12" json:"default_quota"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

func (LeaveType) TableName() string {
	return "TB_M_LEAVE_TYPE"
}

// Transaction Tables
type Attendance struct {
	ID              uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID          uint       `gorm:"not null;index" json:"user_id"`
	User            *User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Date            string     `gorm:"size:10;not null;index" json:"date"` // YYYY-MM-DD
	CheckInTime     *time.Time `json:"check_in_time"`
	CheckInLat      float64    `json:"check_in_lat"`
	CheckInLong     float64    `json:"check_in_long"`
	CheckInAddress  string     `gorm:"size:255" json:"check_in_address"`
	CheckOutTime    *time.Time `json:"check_out_time"`
	CheckOutLat     float64    `json:"check_out_lat"`
	CheckOutLong    float64    `json:"check_out_long"`
	CheckOutAddress string     `gorm:"size:255" json:"check_out_address"`
	Status          string     `gorm:"size:20;default:'PRESENT'" json:"status"` // PRESENT, LATE, ABSENT
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

func (Attendance) TableName() string {
	return "TB_R_ATTENDANCE"
}

type LeaveRequest struct {
	ID          uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID      uint       `gorm:"not null;index" json:"user_id"`
	User        *User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	LeaveTypeID uint       `gorm:"not null" json:"leave_type_id"`
	LeaveType   *LeaveType `gorm:"foreignKey:LeaveTypeID" json:"leave_type,omitempty"`
	StartDate   string     `gorm:"size:10;not null" json:"start_date"` // YYYY-MM-DD
	EndDate     string     `gorm:"size:10;not null" json:"end_date"`   // YYYY-MM-DD
	Reason      string     `gorm:"type:text;not null" json:"reason"`
	Status      string     `gorm:"size:20;default:'PENDING'" json:"status"` // PENDING, APPROVED, REJECTED
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

func (LeaveRequest) TableName() string {
	return "TB_R_LEAVE_REQUEST"
}

type AttendanceCorrection struct {
	ID               uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID           uint       `gorm:"not null;index" json:"user_id"`
	User             *User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	AttendanceDate   string     `gorm:"size:10;not null" json:"attendance_date"` // YYYY-MM-DD
	CorrectedCheckIn *time.Time `json:"corrected_check_in"`
	CorrectedCheckOut *time.Time `json:"corrected_check_out"`
	Reason           string     `gorm:"type:text;not null" json:"reason"`
	Status           string     `gorm:"size:20;default:'PENDING'" json:"status"` // PENDING, APPROVED, REJECTED
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

func (AttendanceCorrection) TableName() string {
	return "TB_R_ATTENDANCE_CORRECTION"
}

// Log Tables
type LogHeader struct {
	ID        uint        `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint        `gorm:"index" json:"user_id"`
	Action    string      `gorm:"size:100;not null" json:"action"`
	ClientIP  string      `gorm:"size:50" json:"client_ip"`
	UserAgent string      `gorm:"size:255" json:"user_agent"`
	CreatedAt time.Time   `json:"created_at"`
	Details   []LogDetail `gorm:"foreignKey:LogHID" json:"details,omitempty"`
}

func (LogHeader) TableName() string {
	return "TB_R_LOG_H"
}

type LogDetail struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	LogHID    uint      `gorm:"not null;index" json:"log_h_id"`
	FieldName string    `gorm:"size:100;not null" json:"field_name"`
	OldValue  string    `gorm:"type:text" json:"old_value"`
	NewValue  string    `gorm:"type:text" json:"new_value"`
	CreatedAt time.Time `json:"created_at"`
}

func (LogDetail) TableName() string {
	return "TB_R_LOG_D"
}

type Notification struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index" json:"user_id"`
	Title     string    `gorm:"size:150;not null" json:"title"`
	Message   string    `gorm:"type:text;not null" json:"message"`
	Type      string    `gorm:"size:50;default:'INFO'" json:"type"`
	Status    string    `gorm:"size:20;default:'INFO'" json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

func (Notification) TableName() string {
	return "TB_R_NOTIFICATION"
}
