package controllers

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tmmin-fid/fid-attendance-system/backend/config"
	"github.com/tmmin-fid/fid-attendance-system/backend/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// Timeline: colleagues share what they did today (text, photo, or both).
// Photos are stored as files under MEDIA_DIR (default ./uploads) and served
// from /api/v1/media/... — never as base64 in the database, so the feed
// stays small and images are cached by the browser/app.

const (
	maxPostText    = 2000
	maxCommentText = 500
	maxImageBytes  = 6 << 20 // 6 MB
)

func MediaDir() string {
	if d := os.Getenv("MEDIA_DIR"); d != "" {
		return d
	}
	return "uploads"
}

type feedAuthor struct {
	ID          uint      `json:"id"`
	Name        string    `json:"name"`
	Department  string    `json:"department"`
	Role        string    `json:"role"`
	AvatarURL   string    `json:"avatar_url"`
	AvatarFrame string    `json:"avatar_frame"`
	TopBadge    *TopBadge `json:"top_badge"`
}

type feedComment struct {
	ID        uint      `json:"id"`
	UserID    uint      `json:"user_id"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"created_at"`
}

type feedPost struct {
	ID           uint          `json:"id"`
	UserID       uint          `json:"user_id"`
	Text         string        `json:"text"`
	ImageURL     string        `json:"image_url"`
	ImageW       int           `json:"image_w"`
	ImageH       int           `json:"image_h"`
	CreatedAt    time.Time     `json:"created_at"`
	LikeCount    int64         `json:"like_count"`
	LikedByMe    bool          `json:"liked_by_me"`
	CommentCount int64         `json:"comment_count"`
	Comments     []feedComment `json:"comments"` // latest few
	CanDelete    bool          `json:"can_delete"`
}

// buildFeed decorates posts with counts and returns the authors once each.
func buildFeed(me models.User, posts []models.Post) ([]feedPost, map[uint]feedAuthor) {
	out := make([]feedPost, 0, len(posts))
	authors := map[uint]feedAuthor{}
	if len(posts) == 0 {
		return out, authors
	}
	ids := make([]uint, len(posts))
	userIDs := map[uint]bool{}
	for i, p := range posts {
		ids[i] = p.ID
		userIDs[p.UserID] = true
	}

	type cnt struct {
		PostID uint
		N      int64
	}
	var likes, comments []cnt
	config.DB.Model(&models.PostLike{}).Select("post_id, count(*) as n").Where("post_id IN ?", ids).Group("post_id").Scan(&likes)
	config.DB.Model(&models.PostComment{}).Select("post_id, count(*) as n").Where("post_id IN ?", ids).Group("post_id").Scan(&comments)
	likeN, commentN := map[uint]int64{}, map[uint]int64{}
	for _, l := range likes {
		likeN[l.PostID] = l.N
	}
	for _, c := range comments {
		commentN[c.PostID] = c.N
	}
	var mine []uint
	config.DB.Model(&models.PostLike{}).Where("post_id IN ? AND user_id = ?", ids, me.ID).Pluck("post_id", &mine)
	likedByMe := map[uint]bool{}
	for _, id := range mine {
		likedByMe[id] = true
	}

	// Latest 2 comments per post (small N, simple query).
	var recent []models.PostComment
	config.DB.Where("post_id IN ?", ids).Order("id desc").Limit(len(ids) * 6).Find(&recent)
	byPost := map[uint][]feedComment{}
	for _, c := range recent {
		if len(byPost[c.PostID]) < 2 {
			byPost[c.PostID] = append([]feedComment{{ID: c.ID, UserID: c.UserID, Text: c.Text, CreatedAt: c.CreatedAt}}, byPost[c.PostID]...)
			userIDs[c.UserID] = true
		}
	}

	uids := make([]uint, 0, len(userIDs))
	for id := range userIDs {
		uids = append(uids, id)
	}
	var users []models.User
	config.DB.Select("id, name, department, role, avatar_url, avatar_frame").Where("id IN ?", uids).Find(&users)
	tops := topBadgesFor(uids)
	for _, u := range users {
		authors[u.ID] = feedAuthor{ID: u.ID, Name: u.Name, Department: u.Department, Role: u.Role, AvatarURL: u.AvatarURL, AvatarFrame: u.AvatarFrame, TopBadge: tops[u.ID]}
	}

	isAdmin := strings.EqualFold(me.Role, models.RoleSuperAdmin)
	for _, p := range posts {
		cs := byPost[p.ID]
		if cs == nil {
			cs = []feedComment{}
		}
		out = append(out, feedPost{
			ID: p.ID, UserID: p.UserID, Text: p.Text, ImageURL: p.ImageURL, ImageW: p.ImageW, ImageH: p.ImageH, CreatedAt: p.CreatedAt,
			LikeCount: likeN[p.ID], LikedByMe: likedByMe[p.ID], CommentCount: commentN[p.ID], Comments: cs,
			CanDelete: p.UserID == me.ID || isAdmin,
		})
	}
	return out, authors
}

func currentUser(c *gin.Context) (models.User, bool) {
	var me models.User
	if err := config.DB.Select("id, name, role").First(&me, c.MustGet("userID").(uint)).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return me, false
	}
	return me, true
}

// GET /timeline?before=ID&limit=20&user_id=ID
func GetTimeline(c *gin.Context) {
	me, ok := currentUser(c)
	if !ok {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	q := config.DB.Order("id desc").Limit(limit)
	if before, _ := strconv.Atoi(c.Query("before")); before > 0 {
		q = q.Where("id < ?", before)
	}
	if uid, _ := strconv.Atoi(c.Query("user_id")); uid > 0 {
		q = q.Where("user_id = ?", uid)
	}
	var posts []models.Post
	if err := q.Find(&posts).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load timeline"})
		return
	}
	feed, authors := buildFeed(me, posts)
	var next any
	if len(posts) == limit {
		next = posts[len(posts)-1].ID
	}
	c.JSON(http.StatusOK, gin.H{"posts": feed, "authors": authors, "next_before": next})
}

// sniffImage validates the upload by content (not by extension).
func sniffImage(head []byte) (string, bool) {
	switch http.DetectContentType(head) {
	case "image/jpeg":
		return ".jpg", true
	case "image/png":
		return ".png", true
	case "image/webp":
		return ".webp", true
	case "image/gif":
		return ".gif", true
	}
	return "", false
}

func randomName() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// POST /timeline/posts (multipart: text, image, image_w, image_h)
func CreatePost(c *gin.Context) {
	me, ok := currentUser(c)
	if !ok {
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxImageBytes+64<<10)
	text := strings.TrimSpace(c.PostForm("text"))
	if len([]rune(text)) > maxPostText {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Text is limited to %d characters", maxPostText)})
		return
	}

	post := models.Post{UserID: me.ID, Text: text}
	if fh, err := c.FormFile("image"); err == nil {
		if fh.Size > maxImageBytes {
			c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "Image is too large (max 6 MB)"})
			return
		}
		src, err := fh.Open()
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Could not read the image"})
			return
		}
		defer src.Close()
		head := make([]byte, 512)
		n, _ := io.ReadFull(src, head)
		ext, okImg := sniffImage(head[:n])
		if !okImg {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Only JPG, PNG, WEBP or GIF images are allowed"})
			return
		}
		dir := filepath.Join(MediaDir(), "timeline", time.Now().Format("200601"))
		if err := os.MkdirAll(dir, 0o755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage unavailable"})
			return
		}
		name := randomName() + ext
		dst, err := os.Create(filepath.Join(dir, name))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage unavailable"})
			return
		}
		_, werr := dst.Write(head[:n])
		if werr == nil {
			_, werr = io.Copy(dst, src)
		}
		dst.Close()
		if werr != nil {
			os.Remove(filepath.Join(dir, name))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save image"})
			return
		}
		post.ImageURL = "/api/v1/media/timeline/" + time.Now().Format("200601") + "/" + name
		post.ImageW, _ = strconv.Atoi(c.PostForm("image_w"))
		post.ImageH, _ = strconv.Atoi(c.PostForm("image_h"))
	}
	if post.Text == "" && post.ImageURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Write something or add a photo"})
		return
	}
	if err := config.DB.Create(&post).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to publish"})
		return
	}
	feed, authors := buildFeed(me, []models.Post{post})
	c.JSON(http.StatusCreated, gin.H{"post": feed[0], "authors": authors})
}

func loadPost(c *gin.Context) (models.Post, bool) {
	var p models.Post
	id, _ := strconv.Atoi(c.Param("id"))
	if err := config.DB.First(&p, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
		return p, false
	}
	return p, true
}

// DELETE /timeline/posts/:id — author or Super Admin.
func DeletePost(c *gin.Context) {
	me, ok := currentUser(c)
	if !ok {
		return
	}
	p, ok := loadPost(c)
	if !ok {
		return
	}
	if p.UserID != me.ID && !strings.EqualFold(me.Role, models.RoleSuperAdmin) {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only delete your own posts"})
		return
	}
	config.DB.Transaction(func(tx *gorm.DB) error {
		tx.Where("post_id = ?", p.ID).Delete(&models.PostLike{})
		tx.Where("post_id = ?", p.ID).Delete(&models.PostComment{})
		return tx.Delete(&p).Error
	})
	if p.ImageURL != "" {
		rel := strings.TrimPrefix(p.ImageURL, "/api/v1/media/")
		os.Remove(filepath.Join(MediaDir(), filepath.FromSlash(rel)))
	}
	c.JSON(http.StatusOK, gin.H{"message": "Post deleted"})
}

// POST /timeline/posts/:id/like — toggles the like.
func ToggleLike(c *gin.Context) {
	me, ok := currentUser(c)
	if !ok {
		return
	}
	p, ok := loadPost(c)
	if !ok {
		return
	}
	res := config.DB.Where("post_id = ? AND user_id = ?", p.ID, me.ID).Delete(&models.PostLike{})
	liked := false
	if res.RowsAffected == 0 {
		config.DB.Clauses(clause.OnConflict{DoNothing: true}).Create(&models.PostLike{PostID: p.ID, UserID: me.ID, CreatedAt: time.Now()})
		liked = true
		if p.UserID != me.ID {
			config.DB.Create(&models.Notification{UserID: p.UserID, Title: "New like ❤", Message: fmt.Sprintf("%s liked your post.", me.Name), Type: "TIMELINE", Status: "INFO", CreatedAt: time.Now()})
		}
	}
	var n int64
	config.DB.Model(&models.PostLike{}).Where("post_id = ?", p.ID).Count(&n)
	c.JSON(http.StatusOK, gin.H{"liked": liked, "like_count": n})
}

// GET /timeline/posts/:id/comments
func GetComments(c *gin.Context) {
	if _, ok := currentUser(c); !ok {
		return
	}
	p, ok := loadPost(c)
	if !ok {
		return
	}
	var list []models.PostComment
	config.DB.Where("post_id = ?", p.ID).Order("id asc").Limit(300).Find(&list)
	ids := map[uint]bool{}
	out := make([]feedComment, 0, len(list))
	for _, cm := range list {
		ids[cm.UserID] = true
		out = append(out, feedComment{ID: cm.ID, UserID: cm.UserID, Text: cm.Text, CreatedAt: cm.CreatedAt})
	}
	uids := make([]uint, 0, len(ids))
	for id := range ids {
		uids = append(uids, id)
	}
	authors := map[uint]feedAuthor{}
	if len(uids) > 0 {
		var users []models.User
		config.DB.Select("id, name, department, role, avatar_url, avatar_frame").Where("id IN ?", uids).Find(&users)
		tops := topBadgesFor(uids)
		for _, u := range users {
			authors[u.ID] = feedAuthor{ID: u.ID, Name: u.Name, Department: u.Department, Role: u.Role, AvatarURL: u.AvatarURL, AvatarFrame: u.AvatarFrame, TopBadge: tops[u.ID]}
		}
	}
	c.JSON(http.StatusOK, gin.H{"comments": out, "authors": authors})
}

// POST /timeline/posts/:id/comments {"text": "..."}
func AddComment(c *gin.Context) {
	me, ok := currentUser(c)
	if !ok {
		return
	}
	p, ok := loadPost(c)
	if !ok {
		return
	}
	var req struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Text) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Comment cannot be empty"})
		return
	}
	text := strings.TrimSpace(req.Text)
	if len([]rune(text)) > maxCommentText {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Comments are limited to %d characters", maxCommentText)})
		return
	}
	cm := models.PostComment{PostID: p.ID, UserID: me.ID, Text: text, CreatedAt: time.Now()}
	if err := config.DB.Create(&cm).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to comment"})
		return
	}
	if p.UserID != me.ID {
		config.DB.Create(&models.Notification{UserID: p.UserID, Title: "New comment 💬", Message: fmt.Sprintf("%s: %s", me.Name, clip(text, 120)), Type: "TIMELINE", Status: "INFO", CreatedAt: time.Now()})
	}
	c.JSON(http.StatusCreated, gin.H{"comment": feedComment{ID: cm.ID, UserID: me.ID, Text: cm.Text, CreatedAt: cm.CreatedAt}})
}
