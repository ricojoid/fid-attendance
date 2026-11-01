package controllers

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
)

// App themes recolour the whole app (web + mobile); some add an animated
// decoration layer (petals, bubbles, monsters…). LIGHT and DARK are free,
// the rest unlock with a badge or are granted by a Super Admin.
// Visual definitions live in the clients, keyed by Code.
type ThemeDef struct {
	Code        string `json:"code"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Source      string `json:"source"` // FREE, ACHIEVEMENT, ADMIN
	Rarity      int    `json:"rarity"`
	BadgeCode   string `json:"badge_code,omitempty"`
	Animated    bool   `json:"animated"`
}

var ThemeCatalog = []ThemeDef{
	{Code: "LIGHT", Name: "Light", Description: "Clean and bright", Source: "FREE", Rarity: 1},
	{Code: "DARK", Name: "Dark", Description: "Easy on the eyes", Source: "FREE", Rarity: 1},
	{Code: "FOREST", Name: "Forest", Description: "Fresh greens with drifting leaves", Source: "ACHIEVEMENT", Rarity: 2, BadgeCode: "STREAK_7D", Animated: true},
	{Code: "OCEAN", Name: "Ocean", Description: "Calm blues with rising bubbles", Source: "ACHIEVEMENT", Rarity: 2, BadgeCode: "OVERTIME_5", Animated: true},
	{Code: "SAKURA", Name: "Sakura", Description: "Soft pink with falling cherry blossoms", Source: "ACHIEVEMENT", Rarity: 3, BadgeCode: "STREAK_1M", Animated: true},
	{Code: "MONSTER", Name: "Monster Party", Description: "Cute little monsters float around your app", Source: "ACHIEVEMENT", Rarity: 3, BadgeCode: "OVERTIME_20", Animated: true},
	{Code: "GOLDEN", Name: "Golden Hour", Description: "Royal gold on deep night", Source: "ACHIEVEMENT", Rarity: 4, BadgeCode: "STREAK_6M", Animated: true},
	{Code: "GALAXY", Name: "Galaxy", Description: "Deep space with twinkling stars", Source: "ACHIEVEMENT", Rarity: 4, BadgeCode: "OVERTIME_50", Animated: true},
	{Code: "CANDY", Name: "Candy Pop", Description: "Pastel sweets — awarded by management", Source: "ADMIN", Rarity: 3, Animated: true},
	{Code: "SUNSET", Name: "Sunset", Description: "Warm sunset with floating clouds", Source: "ADMIN", Rarity: 2, Animated: true},
}

var themeByCode = func() map[string]ThemeDef {
	m := map[string]ThemeDef{}
	for _, t := range ThemeCatalog {
		m[t.Code] = t
	}
	return m
}()

func ownedThemes(userID uint) map[string]gin.H {
	owned := map[string]gin.H{}
	var badges []models.UserBadge
	config.DB.Select("badge_code, earned_at").Where("user_id = ?", userID).Find(&badges)
	earned := map[string]bool{}
	for _, b := range badges {
		earned[b.BadgeCode] = true
	}
	for _, t := range ThemeCatalog {
		switch {
		case t.Source == "FREE":
			owned[t.Code] = gin.H{"via": "free"}
		case t.Source == "ACHIEVEMENT" && earned[t.BadgeCode]:
			owned[t.Code] = gin.H{"via": "achievement"}
		}
	}
	// Admin grants share TB_R_USER_FRAME (it stores any reward code).
	var grants []models.UserFrame
	config.DB.Where("user_id = ?", userID).Find(&grants)
	for _, g := range grants {
		if _, ok := themeByCode[g.FrameCode]; ok {
			owned[g.FrameCode] = gin.H{"via": "admin", "granted_by": g.GrantedByName, "note": g.Note, "obtained_at": g.CreatedAt}
		}
	}
	return owned
}

func themeList(userID uint) ([]gin.H, string) {
	owned := ownedThemes(userID)
	var user models.User
	config.DB.Select("id, app_theme").First(&user, userID)
	list := make([]gin.H, 0, len(ThemeCatalog))
	for _, t := range ThemeCatalog {
		item := gin.H{
			"code": t.Code, "name": t.Name, "description": t.Description, "source": t.Source,
			"rarity": t.Rarity, "badge_code": t.BadgeCode, "animated": t.Animated, "owned": false,
		}
		switch t.Source {
		case "FREE":
			item["unlock_hint"] = "Free for everyone"
		case "ADMIN":
			item["unlock_hint"] = "Awarded by a Super Admin"
		default:
			if b, ok := badgeByCode[t.BadgeCode]; ok {
				item["unlock_hint"] = fmt.Sprintf("Earn the %s badge", b.Name)
			}
		}
		if o, ok := owned[t.Code]; ok {
			item["owned"] = true
			for k, v := range o {
				item[k] = v
			}
		}
		list = append(list, item)
	}
	active := user.AppTheme
	if _, ok := owned[active]; !ok {
		active = "LIGHT"
	}
	return list, active
}

// GET /themes/me
func GetMyThemes(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	list, active := themeList(userID)
	c.JSON(http.StatusOK, gin.H{"themes": list, "active": active})
}

// PUT /themes/equip {"code":"SAKURA"}
func EquipTheme(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	var req struct {
		Code string `json:"code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}
	code := strings.ToUpper(strings.TrimSpace(req.Code))
	if code == "" {
		code = "LIGHT"
	}
	if _, ok := ownedThemes(userID)[code]; !ok {
		c.JSON(http.StatusForbidden, gin.H{"error": "You have not unlocked this theme yet"})
		return
	}
	if err := config.DB.Model(&models.User{}).Where("id = ?", userID).Update("app_theme", code).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to apply theme"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"active": code})
}
