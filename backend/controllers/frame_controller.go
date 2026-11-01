package controllers

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"gorm.io/gorm/clause"
)

// Avatar frames are cosmetic rewards drawn around a user's avatar.
//   - ACHIEVEMENT frames unlock automatically with a badge (derived, not stored).
//   - ADMIN frames are granted by a Super Admin (stored in TB_R_USER_FRAME).
//
// The visual style lives in the clients, keyed by Code.
type FrameDef struct {
	Code        string `json:"code"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Source      string `json:"source"` // ACHIEVEMENT, ADMIN
	Rarity      int    `json:"rarity"` // 1 common .. 4 legendary
	BadgeCode   string `json:"badge_code,omitempty"`
}

var FrameCatalog = []FrameDef{
	// Free starters — everyone owns these.
	{Code: "GLOW", Name: "Soft Glow", Description: "A gentle breathing glow in your theme colour", Source: "FREE", Rarity: 1},
	{Code: "BUBBLES", Name: "Bubbles", Description: "Little bubbles float around you", Source: "FREE", Rarity: 1},
	{Code: "SUNNY", Name: "Sunny Day", Description: "Warm rays that slowly turn", Source: "FREE", Rarity: 1},

	{Code: "EMBER", Name: "Ember", Description: "A warm glow for a 7-day streak", Source: "ACHIEVEMENT", Rarity: 1, BadgeCode: "STREAK_7D"},
	{Code: "BLAZE", Name: "Blaze", Description: "A spinning ring of fire for a 1-month streak", Source: "ACHIEVEMENT", Rarity: 2, BadgeCode: "STREAK_1M"},
	{Code: "INFERNO_CROWN", Name: "Inferno Crown", Description: "Crowned in flames for a 6-month streak", Source: "ACHIEVEMENT", Rarity: 3, BadgeCode: "STREAK_6M"},
	{Code: "PHOENIX", Name: "Phoenix", Description: "Legendary rebirth for a 1-year streak", Source: "ACHIEVEMENT", Rarity: 4, BadgeCode: "STREAK_1Y"},
	{Code: "MOONLIGHT", Name: "Moonlight", Description: "Silver moonlight for 5 overtime days", Source: "ACHIEVEMENT", Rarity: 1, BadgeCode: "OVERTIME_5"},
	{Code: "NIGHT_OWL", Name: "Night Owl", Description: "Starry night for 20 overtime days", Source: "ACHIEVEMENT", Rarity: 2, BadgeCode: "OVERTIME_20"},
	{Code: "GALAXY", Name: "Galaxy", Description: "A swirling nebula for 50 overtime days", Source: "ACHIEVEMENT", Rarity: 3, BadgeCode: "OVERTIME_50"},
	{Code: "ECLIPSE", Name: "Eclipse", Description: "Legendary eclipse for 100 overtime days", Source: "ACHIEVEMENT", Rarity: 4, BadgeCode: "OVERTIME_100"},

	{Code: "EMPLOYEE_OF_MONTH", Name: "Employee of the Month", Description: "Golden laurels, awarded by management", Source: "ADMIN", Rarity: 3},
	{Code: "RISING_STAR", Name: "Rising Star", Description: "For someone who is shining bright", Source: "ADMIN", Rarity: 2},
	{Code: "TEAM_HERO", Name: "Team Hero", Description: "For going above and beyond for the team", Source: "ADMIN", Rarity: 2},
	{Code: "BIRTHDAY", Name: "Birthday", Description: "Party time! 🎉", Source: "ADMIN", Rarity: 1},
	{Code: "FOUNDERS_CIRCLE", Name: "Founder's Circle", Description: "A legendary honour from the leadership", Source: "ADMIN", Rarity: 4},
	{Code: "CHERRY_BLOSSOM", Name: "Cherry Blossom", Description: "Petals swirling around your photo", Source: "ADMIN", Rarity: 2},
	{Code: "NEON_PULSE", Name: "Neon Pulse", Description: "Electric neon that pulses to the beat", Source: "ADMIN", Rarity: 3},
	{Code: "SNOWFALL", Name: "Snowfall", Description: "Cosy snowflakes drifting around", Source: "ADMIN", Rarity: 2},
	{Code: "LIGHTNING", Name: "Lightning", Description: "Crackling electric bolts", Source: "ADMIN", Rarity: 3},
	{Code: "HEARTBEAT", Name: "Heartbeat", Description: "Loved by the team ❤", Source: "ADMIN", Rarity: 2},
	{Code: "DIAMOND", Name: "Diamond", Description: "Prismatic sparkle — the rarest gift", Source: "ADMIN", Rarity: 4},
}

var frameByCode = func() map[string]FrameDef {
	m := map[string]FrameDef{}
	for _, f := range FrameCatalog {
		m[f.Code] = f
	}
	return m
}()

// ownedFrames returns frame code → how it was obtained, for one user.
func ownedFrames(userID uint) map[string]gin.H {
	owned := map[string]gin.H{}
	var badges []models.UserBadge
	config.DB.Select("badge_code, earned_at").Where("user_id = ?", userID).Find(&badges)
	earned := map[string]time.Time{}
	for _, b := range badges {
		earned[b.BadgeCode] = b.EarnedAt
	}
	for _, f := range FrameCatalog {
		switch f.Source {
		case "FREE":
			owned[f.Code] = gin.H{"via": "free"}
		case "ACHIEVEMENT":
			if at, ok := earned[f.BadgeCode]; ok {
				owned[f.Code] = gin.H{"obtained_at": at, "via": "achievement"}
			}
		}
	}
	var grants []models.UserFrame
	config.DB.Where("user_id = ?", userID).Find(&grants)
	for _, g := range grants {
		owned[g.FrameCode] = gin.H{"obtained_at": g.CreatedAt, "via": "admin", "granted_by": g.GrantedByName, "note": g.Note}
	}
	return owned
}

func frameList(userID uint) ([]gin.H, string) {
	owned := ownedFrames(userID)
	var user models.User
	config.DB.Select("id, avatar_frame").First(&user, userID)
	list := make([]gin.H, 0, len(FrameCatalog))
	for _, f := range FrameCatalog {
		item := gin.H{
			"code": f.Code, "name": f.Name, "description": f.Description, "source": f.Source,
			"rarity": f.Rarity, "badge_code": f.BadgeCode, "owned": false,
		}
		switch {
		case f.Source == "FREE":
			item["unlock_hint"] = "Free for everyone"
		case f.BadgeCode != "":
			if b, ok := badgeByCode[f.BadgeCode]; ok {
				item["unlock_hint"] = fmt.Sprintf("Earn the %s badge", b.Name)
			}
		default:
			item["unlock_hint"] = "Awarded by a Super Admin"
		}
		if o, ok := owned[f.Code]; ok {
			item["owned"] = true
			for k, v := range o {
				item[k] = v
			}
		}
		list = append(list, item)
	}
	equipped := user.AvatarFrame
	if _, ok := owned[equipped]; !ok {
		equipped = ""
	}
	return list, equipped
}

// GET /frames/me
func GetMyFrames(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	list, equipped := frameList(userID)
	c.JSON(http.StatusOK, gin.H{"frames": list, "equipped": equipped})
}

// PUT /frames/equip {"code": "BLAZE"} — empty code removes the frame.
func EquipFrame(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	var req struct {
		Code string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}
	code := strings.ToUpper(strings.TrimSpace(req.Code))
	if code != "" {
		if _, ok := ownedFrames(userID)[code]; !ok {
			c.JSON(http.StatusForbidden, gin.H{"error": "You have not unlocked this frame yet"})
			return
		}
	}
	if err := config.DB.Model(&models.User{}).Where("id = ?", userID).Update("avatar_frame", code).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to equip frame"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"equipped": code})
}

// GET /admin/frames/user/:id
func AdminGetUserFrames(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}
	list, equipped := frameList(uint(id))
	themes, active := themeList(uint(id))
	c.JSON(http.StatusOK, gin.H{"frames": list, "equipped": equipped, "themes": themes, "active_theme": active})
}

type grantFrameRequest struct {
	UserID    uint   `json:"user_id" binding:"required"`
	FrameCode string `json:"frame_code" binding:"required"`
	Note      string `json:"note"`
}

// POST /admin/frames/grant — Super Admin awards a frame.
func AdminGrantFrame(c *gin.Context) {
	adminID := c.MustGet("userID").(uint)
	var req grantFrameRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id and frame_code are required"})
		return
	}
	code := strings.ToUpper(strings.TrimSpace(req.FrameCode))
	// Any ADMIN-source reward can be granted: avatar frames or app themes.
	rewardName, kind := "", ""
	if def, ok := frameByCode[code]; ok && def.Source == "ADMIN" {
		rewardName, kind = def.Name, "avatar frame"
	} else if t, ok := themeByCode[code]; ok && t.Source == "ADMIN" {
		rewardName, kind = t.Name, "app theme"
	} else {
		c.JSON(http.StatusBadRequest, gin.H{"error": "This reward cannot be granted manually"})
		return
	}
	var target, admin models.User
	if err := config.DB.First(&target, req.UserID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	config.DB.First(&admin, adminID)

	g := models.UserFrame{UserID: target.ID, FrameCode: code, GrantedBy: adminID, GrantedByName: admin.Name, Note: clip(req.Note, 300), CreatedAt: time.Now()}
	res := config.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&g)
	if res.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to grant frame"})
		return
	}
	if res.RowsAffected == 0 {
		c.JSON(http.StatusConflict, gin.H{"error": fmt.Sprintf("%s already owns this reward", target.Name)})
		return
	}
	msg := fmt.Sprintf("%s gave you the \"%s\" %s! Apply it from your profile settings.", admin.Name, rewardName, kind)
	if g.Note != "" {
		msg += " Note: " + g.Note
	}
	config.DB.Create(&models.Notification{UserID: target.ID, Title: fmt.Sprintf("New %s: %s", kind, rewardName), Message: msg, Type: "REWARD", Status: "INFO", CreatedAt: time.Now()})
	c.JSON(http.StatusCreated, gin.H{"message": fmt.Sprintf("%s granted to %s", rewardName, target.Name)})
}

// DELETE /admin/frames/grant?user_id=&frame_code=
func AdminRevokeFrame(c *gin.Context) {
	uid, _ := strconv.ParseUint(c.Query("user_id"), 10, 64)
	code := strings.ToUpper(strings.TrimSpace(c.Query("frame_code")))
	if uid == 0 || code == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id and frame_code are required"})
		return
	}
	config.DB.Where("user_id = ? AND frame_code = ?", uid, code).Delete(&models.UserFrame{})
	// Unequip if it was being worn / used.
	config.DB.Model(&models.User{}).Where("id = ? AND avatar_frame = ?", uid, code).Update("avatar_frame", "")
	config.DB.Model(&models.User{}).Where("id = ? AND app_theme = ?", uid, code).Update("app_theme", "LIGHT")
	c.JSON(http.StatusOK, gin.H{"message": "Frame revoked"})
}
