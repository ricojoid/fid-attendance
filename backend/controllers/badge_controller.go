package controllers

import (
	"fmt"
	"log"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"gorm.io/gorm/clause"
)

// Working-day rules used by the badge engine.
//
//   - A working day is 9 hours on site: 8 hours of work + 1 hour break.
//   - A day counts as overtime only when check-out minus check-in is MORE than 9h.
//     (On site for exactly 8h means only 7h of actual work, which is not overtime.)
//   - Every live check-in day adds 1 to the streak. Missing a weekday breaks it;
//     weekends are optional (checking in adds, skipping never breaks).
const (
	ShiftSpan    = 9 * time.Hour
	BreakPerDay  = 1 * time.Hour
	dateLayout   = "2006-01-02"
	categoryStrk = "STREAK"
	categoryOT   = "OVERTIME"
)

type BadgeDef struct {
	Code        string `json:"code"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Category    string `json:"category"` // STREAK, OVERTIME
	Tier        int    `json:"tier"`     // 1 bronze, 2 silver, 3 gold, 4 legendary
	Target      int    `json:"target"`
	Unit        string `json:"unit"`
}

// Streak targets are expressed in weekdays: 1 month ≈ 22, 6 months ≈ 130, 1 year = 260.
var BadgeCatalog = []BadgeDef{
	{Code: "STREAK_7D", Name: "Week Warrior", Description: "Check in 7 weekdays in a row", Category: categoryStrk, Tier: 1, Target: 7, Unit: "weekdays"},
	{Code: "STREAK_1M", Name: "Monthly Momentum", Description: "Keep a 1-month streak (22 weekdays in a row)", Category: categoryStrk, Tier: 2, Target: 22, Unit: "weekdays"},
	{Code: "STREAK_6M", Name: "Half-Year Hero", Description: "Keep a 6-month streak (130 weekdays in a row)", Category: categoryStrk, Tier: 3, Target: 130, Unit: "weekdays"},
	{Code: "STREAK_1Y", Name: "Year Legend", Description: "Keep a 1-year streak (260 weekdays in a row)", Category: categoryStrk, Tier: 4, Target: 260, Unit: "weekdays"},

	{Code: "OVERTIME_5", Name: "Extra Mile", Description: "Work overtime (more than 9h on site) on 5 days", Category: categoryOT, Tier: 1, Target: 5, Unit: "overtime days"},
	{Code: "OVERTIME_20", Name: "Night Owl", Description: "Work overtime on 20 days", Category: categoryOT, Tier: 2, Target: 20, Unit: "overtime days"},
	{Code: "OVERTIME_50", Name: "Overtime Titan", Description: "Work overtime on 50 days", Category: categoryOT, Tier: 3, Target: 50, Unit: "overtime days"},
	{Code: "OVERTIME_100", Name: "Iron Worker", Description: "Work overtime on 100 days", Category: categoryOT, Tier: 4, Target: 100, Unit: "overtime days"},
}

type BadgeStats struct {
	CurrentStreak        int    `json:"current_streak"`
	LongestStreak        int    `json:"longest_streak"`
	StreakAliveToday     bool   `json:"streak_alive_today"` // false = today is a weekday and not checked in yet
	TotalPresentDays     int    `json:"total_present_days"`
	OvertimeDays         int    `json:"overtime_days"`
	OvertimeMinutes      int    `json:"overtime_minutes"`
	OvertimeDaysThisMon  int    `json:"overtime_days_this_month"`
	EffectiveWorkMinutes int    `json:"effective_work_minutes"` // on-site time minus 1h break per completed day
	LastOvertimeDate     string `json:"last_overtime_date,omitempty"`
}

type BadgeStatus struct {
	BadgeDef
	Earned   bool       `json:"earned"`
	EarnedAt *time.Time `json:"earned_at"`
	Progress int        `json:"progress"` // current value toward Target
	Percent  float64    `json:"percent"`  // 0..1
	IsNew    bool       `json:"is_new"`   // earned but not yet acknowledged by the user
	// RewardFrame is the avatar frame this badge unlocks.
	RewardFrame string `json:"reward_frame,omitempty"`
	RewardTheme string `json:"reward_theme,omitempty"`
}

type badgeEvaluation struct {
	stats    BadgeStats
	earnedOn map[string]time.Time // badge code → date it was (first) achieved
}

// attendanceRow is a narrow projection so we don't load addresses/coordinates.
type attendanceRow struct {
	Date         string
	CheckInTime  *time.Time
	CheckOutTime *time.Time
	Source       string
	IsCorrected  bool
}

// isLive: only real check-ins from the app count for streaks; days that exist
// only because a correction/request was approved do not.
func (r attendanceRow) isLive() bool { return r.Source == "" || r.Source == "LIVE" }

func isWeekday(t time.Time) bool {
	wd := t.Weekday()
	return wd != time.Saturday && wd != time.Sunday
}

// evaluate is pure: given attendance rows it computes stats and the date
// each badge was first achieved. Rows may be in any order.
func evaluate(rows []attendanceRow, now time.Time) badgeEvaluation {
	ev := badgeEvaluation{earnedOn: map[string]time.Time{}}

	present := make(map[string]bool, len(rows))
	type otDay struct {
		date string
		mins int
	}
	var otDays []otDay
	earliest := ""
	thisMonth := now.Format("2006-01")

	for _, r := range rows {
		if r.CheckInTime == nil || !r.isLive() {
			continue
		}
		present[r.Date] = true
		if earliest == "" || r.Date < earliest {
			earliest = r.Date
		}
		// Overtime must come from live check-in AND check-out; times edited by a
		// correction request can't be used to farm overtime badges.
		if r.CheckOutTime != nil && !r.IsCorrected {
			span := r.CheckOutTime.Sub(*r.CheckInTime)
			if span > 0 {
				eff := span - BreakPerDay
				if eff < 0 {
					eff = 0
				}
				ev.stats.EffectiveWorkMinutes += int(eff.Minutes())
			}
			if span > ShiftSpan {
				otDays = append(otDays, otDay{date: r.Date, mins: int((span - ShiftSpan).Minutes())})
			}
		}
	}
	ev.stats.TotalPresentDays = len(present)

	// Overtime: sort chronologically so the Nth overtime day is the unlock date.
	sort.Slice(otDays, func(i, j int) bool { return otDays[i].date < otDays[j].date })
	for i, d := range otDays {
		ev.stats.OvertimeMinutes += d.mins
		if len(d.date) >= 7 && d.date[:7] == thisMonth {
			ev.stats.OvertimeDaysThisMon++
		}
		for _, b := range BadgeCatalog {
			if b.Category == categoryOT && i+1 == b.Target {
				if t, err := time.ParseInLocation(dateLayout, d.date, time.Local); err == nil {
					ev.earnedOn[b.Code] = t
				}
			}
		}
	}
	ev.stats.OvertimeDays = len(otDays)
	if n := len(otDays); n > 0 {
		ev.stats.LastOvertimeDate = otDays[n-1].date
	}

	if earliest == "" {
		ev.stats.StreakAliveToday = !isWeekday(now)
		return ev
	}

	// Streak: walk every weekday from the first attendance to today.
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)
	start, err := time.ParseInLocation(dateLayout, earliest, time.Local)
	if err != nil {
		return ev
	}
	run, longest := 0, 0
	for d := start; !d.After(today); d = d.AddDate(0, 0, 1) {
		key := d.Format(dateLayout)
		// Weekends are optional: a live check-in on Sat/Sun adds to the streak,
		// but skipping the weekend never breaks it.
		if !isWeekday(d) && !present[key] {
			continue
		}
		if present[key] {
			run++
			if run > longest {
				longest = run
			}
			for _, b := range BadgeCatalog {
				if b.Category == categoryStrk && run == b.Target {
					if _, ok := ev.earnedOn[b.Code]; !ok {
						ev.earnedOn[b.Code] = d
					}
				}
			}
		} else if d.Equal(today) {
			// Today is still in progress: not checking in *yet* doesn't break the streak.
			break
		} else {
			run = 0
		}
	}
	ev.stats.CurrentStreak = run
	ev.stats.LongestStreak = longest
	ev.stats.StreakAliveToday = !isWeekday(today) || present[today.Format(dateLayout)]
	return ev
}

func loadAttendanceRows(userID uint) ([]attendanceRow, error) {
	var rows []attendanceRow
	err := config.DB.Model(&models.Attendance{}).
		Select("date, check_in_time, check_out_time, source, is_corrected").
		Where("user_id = ?", userID).
		Scan(&rows).Error
	return rows, err
}

// syncBadges evaluates the user's badges, persists any newly earned ones and
// sends a notification for each new unlock. Safe to call concurrently.
func syncBadges(userID uint) (badgeEvaluation, map[string]models.UserBadge, error) {
	rows, err := loadAttendanceRows(userID)
	if err != nil {
		return badgeEvaluation{}, nil, err
	}
	ev := evaluate(rows, time.Now())

	var stored []models.UserBadge
	config.DB.Where("user_id = ?", userID).Find(&stored)
	owned := make(map[string]models.UserBadge, len(stored))
	for _, ub := range stored {
		owned[ub.BadgeCode] = ub
	}

	for _, b := range BadgeCatalog {
		at, ok := ev.earnedOn[b.Code]
		if !ok {
			continue
		}
		if _, have := owned[b.Code]; have {
			continue
		}
		ub := models.UserBadge{UserID: userID, BadgeCode: b.Code, EarnedAt: at, CreatedAt: time.Now()}
		res := config.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&ub)
		if res.Error != nil {
			log.Printf("badge insert failed user=%d code=%s: %v", userID, b.Code, res.Error)
			continue
		}
		if res.RowsAffected == 1 {
			owned[b.Code] = ub
			config.DB.Create(&models.Notification{
				UserID:    userID,
				Title:     fmt.Sprintf("Badge Unlocked: %s", b.Name),
				Message:   fmt.Sprintf("Congratulations! You earned the \"%s\" badge — %s.", b.Name, b.Description),
				Type:      "BADGE",
				Status:    "INFO",
				CreatedAt: time.Now(),
			})
		} else {
			// Another request inserted it first; reload so we have its row.
			var existing models.UserBadge
			if config.DB.Where("user_id = ? AND badge_code = ?", userID, b.Code).First(&existing).Error == nil {
				owned[b.Code] = existing
			}
		}
	}
	return ev, owned, nil
}

// syncBadgesAsync is fired after check-in/out so unlock notifications arrive
// without slowing down the attendance request itself.
func syncBadgesAsync(userID uint) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("badge sync panic: %v", r)
			}
		}()
		if _, _, err := syncBadges(userID); err != nil {
			log.Printf("badge sync failed user=%d: %v", userID, err)
		}
	}()
}

func buildBadgeResponse(ev badgeEvaluation, owned map[string]models.UserBadge, includeNew bool) gin.H {
	list := make([]BadgeStatus, 0, len(BadgeCatalog))
	var newly []BadgeStatus
	earnedCount := 0

	for _, b := range BadgeCatalog {
		st := BadgeStatus{BadgeDef: b}
		for _, f := range FrameCatalog {
			if f.BadgeCode == b.Code {
				st.RewardFrame = f.Code
			}
		}
		for _, t := range ThemeCatalog {
			if t.BadgeCode == b.Code {
				st.RewardTheme = t.Code
			}
		}
		if b.Category == categoryStrk {
			st.Progress = ev.stats.CurrentStreak
		} else {
			st.Progress = ev.stats.OvertimeDays
		}
		if ub, ok := owned[b.Code]; ok {
			earnedAt := ub.EarnedAt
			st.Earned = true
			st.EarnedAt = &earnedAt
			st.Progress = b.Target
			st.IsNew = includeNew && !ub.Seen
			earnedCount++
		}
		if st.Progress > b.Target {
			st.Progress = b.Target
		}
		st.Percent = float64(st.Progress) / float64(b.Target)
		if st.IsNew {
			newly = append(newly, st)
		}
		list = append(list, st)
	}

	// The next badge to chase in each category (first locked one).
	next := gin.H{}
	for _, cat := range []string{categoryStrk, categoryOT} {
		for _, st := range list {
			if st.Category == cat && !st.Earned {
				next[cat] = st
				break
			}
		}
	}

	if newly == nil {
		newly = []BadgeStatus{}
	}
	return gin.H{
		"featured":       "",
		"stats":          ev.stats,
		"badges":         list,
		"newly_unlocked": newly,
		"next":           next,
		"earned_count":   earnedCount,
		"total_count":    len(BadgeCatalog),
		"rules": gin.H{
			"shift_hours":        9,
			"work_hours":         8,
			"break_hours":        1,
			"overtime_threshold": "check-out minus check-in greater than 9 hours",
			"streak_days":        "every live check-in counts (even a single day); missing a weekday breaks it, weekends never do; days from approved correction requests are not counted",
		},
	}
}

// GET /badges/me
func GetMyBadges(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	ev, owned, err := syncBadges(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to evaluate badges"})
		return
	}
	resp := buildBadgeResponse(ev, owned, true)
	var me models.User
	config.DB.Select("id, featured_badge").First(&me, userID)
	resp["featured"] = me.FeaturedBadge
	c.JSON(http.StatusOK, resp)
}

// PUT /badges/feature {"code":"STREAK_1M"} — choose the badge colleagues see
// next to your name. Empty code = automatically show the best one.
func FeatureBadge(c *gin.Context) {
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
		var n int64
		config.DB.Model(&models.UserBadge{}).Where("user_id = ? AND badge_code = ?", userID, code).Count(&n)
		if n == 0 {
			c.JSON(http.StatusForbidden, gin.H{"error": "You have not earned this badge yet"})
			return
		}
	}
	if err := config.DB.Model(&models.User{}).Where("id = ?", userID).Update("featured_badge", code).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"featured": code})
}

// GET /badges/user/:id — read-only view of a colleague's badges.
func GetUserBadges(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil || id == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}
	ev, owned, err := syncBadges(uint(id))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to evaluate badges"})
		return
	}
	c.JSON(http.StatusOK, buildBadgeResponse(ev, owned, false))
}

// POST /badges/seen — acknowledge unlock celebrations so they show only once.
func MarkBadgesSeen(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	var req struct {
		Codes []string `json:"codes"`
	}
	_ = c.ShouldBindJSON(&req)

	q := config.DB.Model(&models.UserBadge{}).Where("user_id = ? AND seen = ?", userID, false)
	if len(req.Codes) > 0 {
		q = q.Where("badge_code IN ?", req.Codes)
	}
	if err := q.Update("seen", true).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update badges"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Badges acknowledged"})
}

// TopBadge is the single "best" badge shown next to a user's name in lists.
type TopBadge struct {
	Code     string `json:"code"`
	Name     string `json:"name"`
	Category string `json:"category"`
	Tier     int    `json:"tier"`
	Target   int    `json:"target"`
	Earned   bool   `json:"earned"`
	Count    int    `json:"count"` // total badges this user owns
}

var badgeByCode = func() map[string]BadgeDef {
	m := map[string]BadgeDef{}
	for _, b := range BadgeCatalog {
		m[b.Code] = b
	}
	return m
}()

// topBadgesFor returns each user's highest-tier badge with ONE query.
// Ties prefer streak badges (consistency is the headline achievement).
func topBadgesFor(userIDs []uint) map[uint]*TopBadge {
	out := map[uint]*TopBadge{}
	if len(userIDs) == 0 {
		return out
	}
	var rows []models.UserBadge
	config.DB.Select("user_id, badge_code").Where("user_id IN ?", userIDs).Find(&rows)
	// Badges users chose to feature themselves.
	var prefs []models.User
	config.DB.Select("id, featured_badge").Where("id IN ? AND featured_badge <> ''", userIDs).Find(&prefs)
	featured := map[uint]string{}
	for _, u := range prefs {
		featured[u.ID] = u.FeaturedBadge
	}
	for _, r := range rows {
		def, ok := badgeByCode[r.BadgeCode]
		if !ok {
			continue
		}
		cur := out[r.UserID]
		if cur == nil {
			cur = &TopBadge{}
			out[r.UserID] = cur
		}
		cur.Count++
		chosen := featured[r.UserID]
		better := def.Tier > cur.Tier || (def.Tier == cur.Tier && def.Category == categoryStrk && cur.Category != categoryStrk)
		if chosen != "" {
			// A featured badge always wins; others never replace it.
			better = def.Code == chosen || (cur.Code != chosen && better)
		}
		if better {
			count := cur.Count
			*cur = TopBadge{Code: def.Code, Name: def.Name, Category: def.Category, Tier: def.Tier, Target: def.Target, Earned: true, Count: count}
		}
	}
	return out
}

// StartBadgeScheduler keeps every user's badges up to date in the background
// (so colleagues see each other's badges even if they never open the badge
// screen). Runs once at start-up and then every 6 hours.
func StartBadgeScheduler() {
	go func() {
		for {
			var ids []uint
			config.DB.Model(&models.User{}).Pluck("id", &ids)
			for _, id := range ids {
				if _, _, err := syncBadges(id); err != nil {
					log.Printf("badge scheduler: user %d: %v", id, err)
				}
			}
			time.Sleep(6 * time.Hour)
		}
	}()
}
