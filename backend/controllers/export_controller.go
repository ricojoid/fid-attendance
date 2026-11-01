package controllers

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"github.com/xuri/excelize/v2"
)

// GET /attendance/export?from=YYYY-MM-DD&to=YYYY-MM-DD[&user_id=ID]
//
// Builds a styled .xlsx with three sheets:
//   - Summary  — one row per employee for the period (check-ins, late, leave,
//     absent, hours, overtime, attendance rate)
//   - Detail   — one row per employee per day with times, durations and locations
//   - Daily    — one row per day with headcounts
//
// Access follows the same hierarchy as the monitoring dashboard.
func ExportAttendanceExcel(c *gin.Context) {
	requesterID := c.MustGet("userID").(uint)
	var requester models.User
	if err := config.DB.First(&requester, requesterID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	now := time.Now()
	fromStr := c.DefaultQuery("from", now.Format("2006-01")+"-01")
	toStr := c.DefaultQuery("to", now.Format(dateLayout))
	from, e1 := time.ParseInLocation(dateLayout, fromStr, time.Local)
	to, e2 := time.ParseInLocation(dateLayout, toStr, time.Local)
	if e1 != nil || e2 != nil || to.Before(from) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "from/to must be YYYY-MM-DD and from <= to"})
		return
	}
	if to.Sub(from) > 366*24*time.Hour {
		c.JSON(http.StatusBadRequest, gin.H{"error": "The export range is limited to one year"})
		return
	}

	usersQ := scopedUsersQuery(requester)
	if uidStr := c.Query("user_id"); uidStr != "" {
		uid, err := strconv.ParseUint(uidStr, 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user_id"})
			return
		}
		var target models.User
		if err := config.DB.First(&target, uid).Error; err != nil || !canViewTargetAttendance(requester, target) {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not allowed to export this employee"})
			return
		}
		usersQ = config.DB.Model(&models.User{}).Where("id = ?", uid)
	}

	var users []models.User
	usersQ.Omit("avatar_url", "password_hash").Order("department asc, name asc").Find(&users)
	ids := make([]uint, len(users))
	for i, u := range users {
		ids[i] = u.ID
	}

	var atts []models.Attendance
	var leaves []models.LeaveRequest
	if len(ids) > 0 {
		config.DB.Where("user_id IN ? AND date >= ? AND date <= ?", ids, fromStr, toStr).Order("date asc").Find(&atts)
		config.DB.Preload("LeaveType").Where("user_id IN ? AND status = ? AND start_date <= ? AND end_date >= ?", ids, "APPROVED", toStr, fromStr).Find(&leaves)
	}
	attBy := map[uint]map[string]models.Attendance{}
	for _, a := range atts {
		if attBy[a.UserID] == nil {
			attBy[a.UserID] = map[string]models.Attendance{}
		}
		attBy[a.UserID][a.Date] = a
	}
	leaveOn := func(uid uint, d string) *models.LeaveRequest {
		for i := range leaves {
			l := &leaves[i]
			if l.UserID == uid && l.StartDate <= d && l.EndDate >= d {
				return l
			}
		}
		return nil
	}

	f := excelize.NewFile()
	defer f.Close()
	st := newExportStyles(f)

	period := fmt.Sprintf("%s – %s", from.Format("02 Jan 2006"), to.Format("02 Jan 2006"))
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)

	// ------------------------------------------------------------------ Summary
	sum := "Summary"
	f.SetSheetName("Sheet1", sum)
	sumHeaders := []string{"No", "Employee", "NIP", "Department", "Role", "Working Days", "Check-ins", "On Time", "Late", "Leave", "Absent", "Corrections", "Total On-site (h)", "Effective Work (h)", "Overtime Days", "Overtime (h)", "Attendance Rate"}
	writeTitle(f, sum, st, "Attendance Summary", period, len(sumHeaders))
	writeHeader(f, sum, st, 4, sumHeaders)

	type dayRow struct {
		present, late, leave, absent int
	}
	daily := map[string]*dayRow{}
	var days []time.Time
	for d := from; !d.After(to); d = d.AddDate(0, 0, 1) {
		days = append(days, d)
		daily[d.Format(dateLayout)] = &dayRow{}
	}

	// ------------------------------------------------------------------ Detail
	det := "Detail"
	f.NewSheet(det)
	detHeaders := []string{"Date", "Day", "Employee", "NIP", "Department", "Status", "Check-in", "Check-out", "On-site", "Effective Work", "Overtime", "Check-in Location", "Check-out Location", "Check-in Coordinates", "GPS Accuracy (m)", "Note", "Source"}
	writeTitle(f, det, st, "Attendance Detail", period, len(detHeaders))
	writeHeader(f, det, st, 4, detHeaders)
	detRow := 5

	for i, u := range users {
		workDays, checkins, onTime, late, leaveDays, absent, corrections, otDays := 0, 0, 0, 0, 0, 0, 0, 0
		var onSite, effective, overtime time.Duration
		for _, d := range days {
			ds := d.Format(dateLayout)
			weekday := isWeekday(d)
			if weekday {
				workDays++
			}
			a, has := attBy[u.ID][ds]
			status, statusStyle := "", st.cell
			var inT, outT, siteT, effT, otT, inLoc, outLoc, coord, acc, note, source string

			switch {
			case has && a.CheckInTime != nil:
				checkins++
				if a.Source == "CORRECTION" || a.IsCorrected {
					corrections++
				}
				if strings.ToUpper(a.Status) == "LATE" {
					late++
					status, statusStyle = "Late", st.late
					daily[ds].late++
				} else {
					onTime++
					status, statusStyle = "On Time", st.present
					daily[ds].present++
				}
				inT = a.CheckInTime.Format("15:04")
				inLoc, note = a.CheckInAddress, a.CheckInNote
				if a.CheckInLat != 0 || a.CheckInLong != 0 {
					coord = fmt.Sprintf("%.6f, %.6f", a.CheckInLat, a.CheckInLong)
				}
				if a.CheckInAccuracy > 0 {
					acc = fmt.Sprintf("%.0f", a.CheckInAccuracy)
				}
				source = map[bool]string{true: "Correction", false: "Live"}[a.Source == "CORRECTION"]
				if a.CheckOutTime != nil {
					outT = a.CheckOutTime.Format("15:04")
					outLoc = a.CheckOutAddress
					span := a.CheckOutTime.Sub(*a.CheckInTime)
					if span > 0 {
						onSite += span
						eff := span - BreakPerDay
						if eff < 0 {
							eff = 0
						}
						effective += eff
						siteT, effT = hm(span), hm(eff)
						if span > ShiftSpan {
							otDays++
							overtime += span - ShiftSpan
							otT = hm(span - ShiftSpan)
						}
					}
				}
			case leaveOn(u.ID, ds) != nil:
				if weekday {
					leaveDays++
					daily[ds].leave++
				}
				l := leaveOn(u.ID, ds)
				status, statusStyle = "Leave", st.leave
				if l.LeaveType != nil {
					status = "Leave · " + l.LeaveType.Name
				}
				note = l.Reason
			case !weekday:
				status, statusStyle = "Weekend", st.weekend
			case d.After(today):
				status, statusStyle = "Upcoming", st.weekend
			default:
				absent++
				daily[ds].absent++
				status, statusStyle = "Absent", st.absent
			}

			row := []interface{}{d.Format("2006-01-02"), d.Format("Monday"), u.Name, u.NIP, u.Department, status, inT, outT, siteT, effT, otT, inLoc, outLoc, coord, acc, note, source}
			writeRow(f, det, detRow, row, st.rowStyle(detRow))
			cell, _ := excelize.CoordinatesToCellName(6, detRow)
			f.SetCellStyle(det, cell, cell, statusStyle)
			detRow++
		}

		rate := 0.0
		if workDays > 0 {
			rate = float64(checkins) / float64(workDays)
			if rate > 1 {
				rate = 1
			}
		}
		r := 5 + i
		writeRow(f, sum, r, []interface{}{
			i + 1, u.Name, u.NIP, u.Department, prettyRole(u.Role), workDays, checkins, onTime, late, leaveDays, absent, corrections,
			round2(onSite.Hours()), round2(effective.Hours()), otDays, round2(overtime.Hours()), rate,
		}, st.rowStyle(r))
		a, _ := excelize.CoordinatesToCellName(13, r)
		b, _ := excelize.CoordinatesToCellName(14, r)
		f.SetCellStyle(sum, a, b, st.hours(r))
		pc, _ := excelize.CoordinatesToCellName(16, r)
		f.SetCellStyle(sum, pc, pc, st.hours(r))
		rc, _ := excelize.CoordinatesToCellName(17, r)
		f.SetCellStyle(sum, rc, rc, st.percent(r))
	}
	if len(users) > 0 {
		last := 4 + len(users)
		// Totals row.
		tr := last + 1
		f.SetCellValue(sum, fmt.Sprintf("B%d", tr), "TOTAL")
		for col := 6; col <= 16; col++ {
			colName, _ := excelize.ColumnNumberToName(col)
			f.SetCellFormula(sum, fmt.Sprintf("%s%d", colName, tr), fmt.Sprintf("SUM(%s5:%s%d)", colName, colName, last))
		}
		f.SetCellFormula(sum, fmt.Sprintf("Q%d", tr), fmt.Sprintf("IFERROR(G%d/F%d,0)", tr, tr))
		a, _ := excelize.CoordinatesToCellName(1, tr)
		b, _ := excelize.CoordinatesToCellName(len(sumHeaders), tr)
		f.SetCellStyle(sum, a, b, st.total)
		f.SetCellStyle(sum, fmt.Sprintf("Q%d", tr), fmt.Sprintf("Q%d", tr), st.totalPercent)
		f.AutoFilter(sum, fmt.Sprintf("A4:%s%d", colLetter(len(sumHeaders)), last), nil)
	}
	setWidths(f, sum, []float64{6, 28, 12, 24, 16, 13, 11, 10, 8, 8, 9, 12, 16, 17, 14, 13, 15})
	freeze(f, sum, "C5")

	setWidths(f, det, []float64{12, 12, 26, 11, 22, 20, 10, 10, 10, 14, 10, 46, 46, 24, 15, 34, 12})
	freeze(f, det, "D5")
	if detRow > 5 {
		f.AutoFilter(det, fmt.Sprintf("A4:%s%d", colLetter(len(detHeaders)), detRow-1), nil)
	}

	// ------------------------------------------------------------------ Daily
	dly := "Daily Recap"
	f.NewSheet(dly)
	dlyHeaders := []string{"Date", "Day", "Employees", "On Time", "Late", "Leave", "Absent", "Attendance Rate"}
	writeTitle(f, dly, st, "Daily Recap", period, len(dlyHeaders))
	writeHeader(f, dly, st, 4, dlyHeaders)
	sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
	for i, d := range days {
		r := 5 + i
		dr := daily[d.Format(dateLayout)]
		rate := 0.0
		if n := len(users); n > 0 && isWeekday(d) {
			rate = float64(dr.present+dr.late) / float64(n)
		}
		style := st.rowStyle(r)
		if !isWeekday(d) {
			style = st.weekend
		}
		writeRow(f, dly, r, []interface{}{d.Format("2006-01-02"), d.Format("Monday"), len(users), dr.present, dr.late, dr.leave, dr.absent, rate}, style)
		rc, _ := excelize.CoordinatesToCellName(8, r)
		if isWeekday(d) {
			f.SetCellStyle(dly, rc, rc, st.percent(r))
		}
	}
	setWidths(f, dly, []float64{13, 13, 12, 10, 8, 8, 9, 16})
	freeze(f, dly, "A5")

	f.SetActiveSheet(0)
	name := fmt.Sprintf("attendance_%s_to_%s.xlsx", fromStr, toStr)
	if len(users) == 1 && c.Query("user_id") != "" {
		name = fmt.Sprintf("attendance_%s_%s_to_%s.xlsx", strings.ReplaceAll(users[0].Name, " ", "_"), fromStr, toStr)
	}
	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, name))
	c.Header("Access-Control-Expose-Headers", "Content-Disposition")
	if err := f.Write(c.Writer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to build Excel file"})
	}
}

// ----------------------------------------------------------------- helpers

type exportStyles struct {
	title, subtitle, header, cell, cellAlt, total, totalPercent int
	present, late, leave, absent, weekend                       int
	hoursA, hoursB, pctA, pctB                                  int
}

func (s exportStyles) rowStyle(r int) int {
	if r%2 == 0 {
		return s.cellAlt
	}
	return s.cell
}
func (s exportStyles) hours(r int) int {
	if r%2 == 0 {
		return s.hoursB
	}
	return s.hoursA
}
func (s exportStyles) percent(r int) int {
	if r%2 == 0 {
		return s.pctB
	}
	return s.pctA
}

func newExportStyles(f *excelize.File) exportStyles {
	thin := []excelize.Border{
		{Type: "left", Color: "CBD5E1", Style: 1}, {Type: "right", Color: "CBD5E1", Style: 1},
		{Type: "top", Color: "CBD5E1", Style: 1}, {Type: "bottom", Color: "CBD5E1", Style: 1},
	}
	mk := func(s *excelize.Style) int {
		id, _ := f.NewStyle(s)
		return id
	}
	base := func(fill string, numFmt int, custom string) *excelize.Style {
		s := &excelize.Style{
			Border:    thin,
			Font:      &excelize.Font{Family: "Calibri", Size: 10.5, Color: "0F172A"},
			Alignment: &excelize.Alignment{Vertical: "center", WrapText: false},
			NumFmt:    numFmt,
		}
		if custom != "" {
			s.CustomNumFmt = &custom
		}
		if fill != "" {
			s.Fill = excelize.Fill{Type: "pattern", Color: []string{fill}, Pattern: 1}
		}
		return s
	}
	status := func(fill, color string) int {
		s := base(fill, 0, "")
		s.Font = &excelize.Font{Family: "Calibri", Size: 10.5, Bold: true, Color: color}
		s.Alignment = &excelize.Alignment{Horizontal: "center", Vertical: "center"}
		return mk(s)
	}
	totalStyle := base("FDE2E4", 0, "")
	totalStyle.Font = &excelize.Font{Family: "Calibri", Size: 11, Bold: true, Color: "7A0010"}
	totalPct := base("FDE2E4", 0, "0.0%")
	totalPct.Font = totalStyle.Font

	return exportStyles{
		title:    mk(&excelize.Style{Font: &excelize.Font{Family: "Calibri", Size: 16, Bold: true, Color: "B0101F"}}),
		subtitle: mk(&excelize.Style{Font: &excelize.Font{Family: "Calibri", Size: 10.5, Italic: true, Color: "64748B"}}),
		header: mk(&excelize.Style{
			Fill:      excelize.Fill{Type: "pattern", Color: []string{"C8152A"}, Pattern: 1},
			Font:      &excelize.Font{Family: "Calibri", Size: 11, Bold: true, Color: "FFFFFF"},
			Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center", WrapText: true},
			Border: []excelize.Border{
				{Type: "left", Color: "8D0D19", Style: 1}, {Type: "right", Color: "8D0D19", Style: 1},
				{Type: "top", Color: "8D0D19", Style: 1}, {Type: "bottom", Color: "8D0D19", Style: 2},
			},
		}),
		cell:         mk(base("", 0, "")),
		cellAlt:      mk(base("F8FAFC", 0, "")),
		total:        mk(totalStyle),
		totalPercent: mk(totalPct),
		present:      status("DCFCE7", "166534"),
		late:         status("FEF3C7", "92400E"),
		leave:        status("E0F2FE", "075985"),
		absent:       status("FEE2E2", "991B1B"),
		weekend:      mk(base("F1F5F9", 0, "")),
		hoursA:       mk(base("", 0, "0.00")),
		hoursB:       mk(base("F8FAFC", 0, "0.00")),
		pctA:         mk(base("", 0, "0.0%")),
		pctB:         mk(base("F8FAFC", 0, "0.0%")),
	}
}

func writeTitle(f *excelize.File, sheet string, st exportStyles, title, period string, cols int) {
	f.SetCellValue(sheet, "A1", "FID Attendance — "+title)
	f.SetCellStyle(sheet, "A1", "A1", st.title)
	f.SetCellValue(sheet, "A2", fmt.Sprintf("Period: %s  ·  Generated %s", period, time.Now().Format("02 Jan 2006 15:04")))
	f.SetCellStyle(sheet, "A2", "A2", st.subtitle)
	f.MergeCell(sheet, "A1", fmt.Sprintf("%s1", colLetter(cols)))
	f.MergeCell(sheet, "A2", fmt.Sprintf("%s2", colLetter(cols)))
	f.SetRowHeight(sheet, 1, 26)
}

func writeHeader(f *excelize.File, sheet string, st exportStyles, row int, headers []string) {
	for i, h := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, row)
		f.SetCellValue(sheet, cell, h)
	}
	a, _ := excelize.CoordinatesToCellName(1, row)
	b, _ := excelize.CoordinatesToCellName(len(headers), row)
	f.SetCellStyle(sheet, a, b, st.header)
	f.SetRowHeight(sheet, row, 30)
}

func writeRow(f *excelize.File, sheet string, row int, values []interface{}, style int) {
	cell, _ := excelize.CoordinatesToCellName(1, row)
	f.SetSheetRow(sheet, cell, &values)
	b, _ := excelize.CoordinatesToCellName(len(values), row)
	f.SetCellStyle(sheet, cell, b, style)
	f.SetRowHeight(sheet, row, 19)
}

func setWidths(f *excelize.File, sheet string, widths []float64) {
	for i, w := range widths {
		col := colLetter(i + 1)
		f.SetColWidth(sheet, col, col, w)
	}
}

func freeze(f *excelize.File, sheet, topLeft string) {
	col, row, _ := excelize.CellNameToCoordinates(topLeft)
	f.SetPanes(sheet, &excelize.Panes{Freeze: true, XSplit: col - 1, YSplit: row - 1, TopLeftCell: topLeft, ActivePane: "bottomRight"})
}

func colLetter(n int) string {
	s, _ := excelize.ColumnNumberToName(n)
	return s
}

func hm(d time.Duration) string {
	if d < 0 {
		d = 0
	}
	return fmt.Sprintf("%dh %02dm", int(d.Hours()), int(d.Minutes())%60)
}

func round2(v float64) float64 { return float64(int(v*100+0.5)) / 100 }

func prettyRole(r string) string {
	switch strings.ToUpper(r) {
	case models.RoleSuperAdmin:
		return "Super Admin"
	case models.RoleCountryHead:
		return "Country Head"
	case models.RoleManager:
		return "Manager"
	case models.RoleDepartmentHead:
		return "Department Head"
	default:
		return "Employee"
	}
}
