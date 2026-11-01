package controllers

import (
	"testing"
	"time"
)

func at(date string, hh, mm int) *time.Time {
	d, _ := time.ParseInLocation(dateLayout, date, time.Local)
	t := time.Date(d.Year(), d.Month(), d.Day(), hh, mm, 0, 0, time.Local)
	return &t
}

func day(date string, inH, inM, outH, outM int) attendanceRow {
	return attendanceRow{Date: date, CheckInTime: at(date, inH, inM), CheckOutTime: at(date, outH, outM)}
}

func mustDate(s string) time.Time {
	d, _ := time.ParseInLocation(dateLayout, s, time.Local)
	return d
}

// weekdaysFrom returns n consecutive weekday rows starting at start (08:00-17:00).
func weekdaysFrom(start string, n int) []attendanceRow {
	var rows []attendanceRow
	for d := mustDate(start); len(rows) < n; d = d.AddDate(0, 0, 1) {
		if isWeekday(d) {
			rows = append(rows, day(d.Format(dateLayout), 8, 0, 17, 0))
		}
	}
	return rows
}

func TestStreakSkipsWeekends(t *testing.T) {
	// 2026-10-05 is a Monday. 7 weekdays = Mon..Fri + Mon, Tue next week.
	rows := weekdaysFrom("2026-10-05", 7)
	now := mustDate("2026-10-13").Add(18 * time.Hour) // Tuesday evening
	ev := evaluate(rows, now)
	if ev.stats.CurrentStreak != 7 {
		t.Fatalf("want streak 7, got %d", ev.stats.CurrentStreak)
	}
	if _, ok := ev.earnedOn["STREAK_7D"]; !ok {
		t.Fatalf("STREAK_7D should be earned")
	}
	if got := ev.earnedOn["STREAK_7D"].Format(dateLayout); got != "2026-10-13" {
		t.Fatalf("STREAK_7D earned on %s, want 2026-10-13", got)
	}
}

func TestTodayNotCheckedInDoesNotBreakStreak(t *testing.T) {
	rows := weekdaysFrom("2026-10-05", 5)            // Mon..Fri
	now := mustDate("2026-10-12").Add(7 * time.Hour) // next Monday 07:00, not checked in yet
	ev := evaluate(rows, now)
	if ev.stats.CurrentStreak != 5 {
		t.Fatalf("want streak 5 still alive, got %d", ev.stats.CurrentStreak)
	}
	if ev.stats.StreakAliveToday {
		t.Fatalf("streak_alive_today should be false until checking in")
	}
}

func TestMissedWeekdayBreaksStreak(t *testing.T) {
	rows := weekdaysFrom("2026-10-05", 5)               // Mon..Fri
	rows = append(rows, day("2026-10-13", 8, 0, 17, 0)) // skip Monday 12th, attend Tuesday
	now := mustDate("2026-10-13").Add(18 * time.Hour)
	ev := evaluate(rows, now)
	if ev.stats.CurrentStreak != 1 {
		t.Fatalf("want streak 1 after a missed Monday, got %d", ev.stats.CurrentStreak)
	}
	if ev.stats.LongestStreak != 5 {
		t.Fatalf("want longest 5, got %d", ev.stats.LongestStreak)
	}
}

func TestOvertimeRequiresMoreThanNineHours(t *testing.T) {
	rows := []attendanceRow{
		day("2026-10-05", 8, 0, 16, 0),  // 8h on site = 7h work → not overtime
		day("2026-10-06", 8, 0, 17, 0),  // exactly 9h → not overtime
		day("2026-10-07", 8, 0, 17, 1),  // 9h01 → overtime (1 min)
		day("2026-10-08", 8, 0, 19, 30), // 11h30 → overtime (150 min)
	}
	ev := evaluate(rows, mustDate("2026-10-08").Add(20*time.Hour))
	if ev.stats.OvertimeDays != 2 {
		t.Fatalf("want 2 overtime days, got %d", ev.stats.OvertimeDays)
	}
	if ev.stats.OvertimeMinutes != 151 {
		t.Fatalf("want 151 overtime minutes, got %d", ev.stats.OvertimeMinutes)
	}
	// effective work = on-site minus 1h break: 7h + 8h + 8h01 + 10h30
	if want := 7*60 + 8*60 + 8*60 + 1 + 10*60 + 30; ev.stats.EffectiveWorkMinutes != want {
		t.Fatalf("want effective %d, got %d", want, ev.stats.EffectiveWorkMinutes)
	}
}

func TestOvertimeBadgeUnlockDate(t *testing.T) {
	var rows []attendanceRow
	for _, r := range weekdaysFrom("2026-10-05", 6) {
		r.CheckOutTime = at(r.Date, 18, 30) // 10.5h → overtime
		rows = append(rows, r)
	}
	ev := evaluate(rows, mustDate("2026-10-12").Add(20*time.Hour))
	got, ok := ev.earnedOn["OVERTIME_5"]
	if !ok || got.Format(dateLayout) != "2026-10-09" {
		t.Fatalf("OVERTIME_5 should unlock on the 5th overtime day (2026-10-09), got %v %v", got, ok)
	}
	if _, ok := ev.earnedOn["OVERTIME_20"]; ok {
		t.Fatalf("OVERTIME_20 must not be earned yet")
	}
}

func TestOneYearStreak(t *testing.T) {
	rows := weekdaysFrom("2025-10-06", 260)
	last := mustDate(rows[len(rows)-1].Date).Add(18 * time.Hour)
	ev := evaluate(rows, last)
	for _, code := range []string{"STREAK_7D", "STREAK_1M", "STREAK_6M", "STREAK_1Y"} {
		if _, ok := ev.earnedOn[code]; !ok {
			t.Fatalf("%s should be earned after 260 consecutive weekdays", code)
		}
	}
}

func TestCorrectionDaysDoNotCountForStreak(t *testing.T) {
	rows := weekdaysFrom("2026-10-05", 7) // Mon 5 .. Tue 13
	// Wednesday the 7th only exists because a correction request was approved.
	for i := range rows {
		if rows[i].Date == "2026-10-07" {
			rows[i].Source = "CORRECTION"
			rows[i].IsCorrected = true
		}
	}
	ev := evaluate(rows, mustDate("2026-10-13").Add(18*time.Hour))
	if ev.stats.CurrentStreak != 4 { // Thu 8, Fri 9, Mon 12, Tue 13
		t.Fatalf("want streak 4 after a request-only day, got %d", ev.stats.CurrentStreak)
	}
	if _, ok := ev.earnedOn["STREAK_7D"]; ok {
		t.Fatalf("STREAK_7D must not be earned through a correction day")
	}
}

func TestCorrectedTimesDoNotCountAsOvertime(t *testing.T) {
	r := day("2026-10-05", 8, 0, 20, 0) // 12h but edited by a correction
	r.IsCorrected = true
	ev := evaluate([]attendanceRow{r}, mustDate("2026-10-05").Add(21*time.Hour))
	if ev.stats.OvertimeDays != 0 {
		t.Fatalf("corrected day must not count as overtime")
	}
	if ev.stats.CurrentStreak != 1 {
		t.Fatalf("live check-in with corrected times still counts for streak, got %d", ev.stats.CurrentStreak)
	}
}

func TestSingleDayIsAStreakEvenOnWeekend(t *testing.T) {
	// 2026-11-01 is a Sunday.
	ev := evaluate([]attendanceRow{day("2026-11-01", 9, 0, 12, 0)}, mustDate("2026-11-01").Add(13*time.Hour))
	if ev.stats.CurrentStreak != 1 {
		t.Fatalf("a single check-in must be a 1-day streak, got %d", ev.stats.CurrentStreak)
	}
	// Mon..Fri + Saturday check-in, skip Sunday, check in Monday → 7.
	rows := weekdaysFrom("2026-10-05", 5)
	rows = append(rows, day("2026-10-10", 9, 0, 12, 0), day("2026-10-12", 8, 0, 17, 0))
	ev = evaluate(rows, mustDate("2026-10-12").Add(18*time.Hour))
	if ev.stats.CurrentStreak != 7 {
		t.Fatalf("weekend check-in should add, skipped Sunday should not break: got %d", ev.stats.CurrentStreak)
	}
}
