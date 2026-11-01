package models

import (
	"time"
)

// Master Roles
const (
	RoleSuperAdmin     = "SUPER_ADMIN"
	RoleCountryHead    = "COUNTRY_HEAD"
	RoleManager        = "MANAGER"
	RoleDepartmentHead = "DEPARTMENT_HEAD"
	RoleEmployee       = "EMPLOYEE"
)

// Master Departments
var MasterDepartments = []string{
	"App Dev & Data AI",
	"Service Maintenance",
	"Procurement",
	"Sales",
	"Human Resource",
}

// Master Tables
type User struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	NIP           string    `gorm:"size:50;uniqueIndex;not null" json:"nip"`
	Name          string    `gorm:"size:100;not null" json:"name"`
	Email         string    `gorm:"size:100;uniqueIndex;not null" json:"email"`
	PasswordHash  string    `gorm:"size:255;not null" json:"-"`
	Role          string    `gorm:"size:50;default:'EMPLOYEE'" json:"role"` // SUPER_ADMIN, COUNTRY_HEAD, MANAGER, DEPARTMENT_HEAD, EMPLOYEE
	Department    string    `gorm:"size:100" json:"department"`
	AvatarURL     string    `gorm:"type:text" json:"avatar_url"` // may hold a base64 data URI, so must not be varchar(255)
	ApproverName  string    `gorm:"size:100" json:"approver_name"`
	BirthDate     string    `gorm:"size:20" json:"birth_date"`
	AvatarFrame   string    `gorm:"size:40" json:"avatar_frame"`   // equipped cosmetic frame code
	AppTheme      string    `gorm:"size:40" json:"app_theme"`      // active app theme code
	FeaturedBadge string    `gorm:"size:40" json:"featured_badge"` // badge shown next to the name ('' = best one)
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
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
	ID               uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID           uint       `gorm:"not null;index;index:idx_att_user_date,priority:1" json:"user_id"`
	User             *User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Date             string     `gorm:"size:10;not null;index;index:idx_att_user_date,priority:2" json:"date"` // YYYY-MM-DD
	CheckInTime      *time.Time `json:"check_in_time"`
	CheckInLat       float64    `json:"check_in_lat"`
	CheckInLong      float64    `json:"check_in_long"`
	CheckInAddress   string     `gorm:"size:255" json:"check_in_address"`
	CheckInAccuracy  float64    `json:"check_in_accuracy"` // GPS accuracy radius in metres
	CheckInNote      string     `gorm:"type:text" json:"check_in_note"`
	CheckOutTime     *time.Time `json:"check_out_time"`
	CheckOutLat      float64    `json:"check_out_lat"`
	CheckOutLong     float64    `json:"check_out_long"`
	CheckOutAddress  string     `gorm:"size:255" json:"check_out_address"`
	CheckOutAccuracy float64    `json:"check_out_accuracy"`
	CheckOutNote     string     `gorm:"type:text" json:"check_out_note"`
	Status           string     `gorm:"size:20;default:'PRESENT'" json:"status"` // PRESENT, LATE, ABSENT
	// Source: LIVE = real check-in from the app; CORRECTION = record created from an approved request.
	// Only LIVE days count toward streak badges.
	Source string `gorm:"size:20;default:'LIVE'" json:"source"`
	// IsCorrected: times were changed by an approved correction request (excluded from overtime badges).
	IsCorrected bool      `gorm:"default:false" json:"is_corrected"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
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
	Status      string     `gorm:"size:20;default:'PENDING';index" json:"status"` // PENDING, APPROVED, REJECTED
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

func (LeaveRequest) TableName() string {
	return "TB_R_LEAVE_REQUEST"
}

type AttendanceCorrection struct {
	ID                uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID            uint       `gorm:"not null;index" json:"user_id"`
	User              *User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
	AttendanceDate    string     `gorm:"size:10;not null" json:"attendance_date"` // YYYY-MM-DD
	CorrectedCheckIn  *time.Time `json:"corrected_check_in"`
	CorrectedCheckOut *time.Time `json:"corrected_check_out"`
	Reason            string     `gorm:"type:text;not null" json:"reason"`
	Status            string     `gorm:"size:20;default:'PENDING';index" json:"status"` // PENDING, APPROVED, REJECTED
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
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
	IsRead    bool      `gorm:"default:false" json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

func (Notification) TableName() string {
	return "TB_R_NOTIFICATION"
}

type Announcement struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Title     string    `gorm:"size:200;not null" json:"title"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	Category  string    `gorm:"size:50;default:'GENERAL'" json:"category"` // GENERAL, IMPORTANT, EVENT, MAINTENANCE
	AuthorID  uint      `gorm:"not null;index" json:"author_id"`
	Author    *User     `gorm:"foreignKey:AuthorID" json:"author,omitempty"`
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Announcement) TableName() string {
	return "TB_M_ANNOUNCEMENT"
}

// UserBadge stores badges a user has unlocked. Badge progress is computed from
// TB_R_ATTENDANCE on demand; this table only remembers what was already earned
// so a badge is never lost and "new unlock" events fire exactly once.
type UserBadge struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;uniqueIndex:idx_user_badge,priority:1" json:"user_id"`
	BadgeCode string    `gorm:"size:50;not null;uniqueIndex:idx_user_badge,priority:2" json:"badge_code"`
	EarnedAt  time.Time `json:"earned_at"`
	Seen      bool      `gorm:"default:false" json:"seen"`
	CreatedAt time.Time `json:"created_at"`
}

func (UserBadge) TableName() string {
	return "TB_R_USER_BADGE"
}

// UserFrame records avatar frames granted manually by a Super Admin.
// Achievement frames are derived from TB_R_USER_BADGE and not stored here.
type UserFrame struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID        uint      `gorm:"not null;uniqueIndex:idx_user_frame,priority:1" json:"user_id"`
	FrameCode     string    `gorm:"size:40;not null;uniqueIndex:idx_user_frame,priority:2" json:"frame_code"`
	GrantedBy     uint      `json:"granted_by"`
	GrantedByName string    `gorm:"size:100" json:"granted_by_name"`
	Note          string    `gorm:"size:300" json:"note"`
	CreatedAt     time.Time `json:"created_at"`
}

func (UserFrame) TableName() string {
	return "TB_R_USER_FRAME"
}

// Timeline post: text, photo, or both.
type Post struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    uint      `gorm:"not null;index" json:"user_id"`
	Text      string    `gorm:"type:text" json:"text"`
	ImageURL  string    `gorm:"size:255" json:"image_url"`
	ImageW    int       `json:"image_w"`
	ImageH    int       `json:"image_h"`
	CreatedAt time.Time `gorm:"index" json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Post) TableName() string { return "TB_R_POST" }

type PostLike struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	PostID    uint      `gorm:"not null;uniqueIndex:idx_post_like,priority:1;index" json:"post_id"`
	UserID    uint      `gorm:"not null;uniqueIndex:idx_post_like,priority:2" json:"user_id"`
	CreatedAt time.Time `json:"created_at"`
}

func (PostLike) TableName() string { return "TB_R_POST_LIKE" }

type PostComment struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	PostID    uint      `gorm:"not null;index" json:"post_id"`
	UserID    uint      `gorm:"not null" json:"user_id"`
	Text      string    `gorm:"type:text;not null" json:"text"`
	CreatedAt time.Time `json:"created_at"`
}

func (PostComment) TableName() string { return "TB_R_POST_COMMENT" }
