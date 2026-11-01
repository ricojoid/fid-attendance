package controllers

import (
	"encoding/json"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// Live events (Server-Sent Events). Clients keep one long-lived GET
// /api/v1/events open and receive pushes such as new announcements the
// moment they are published — no polling, no refresh.

type liveEvent struct {
	Name string
	Data []byte
}

type eventHub struct {
	mu   sync.RWMutex
	subs map[chan liveEvent]uint // channel → user id
}

var hub = &eventHub{subs: map[chan liveEvent]uint{}}

func (h *eventHub) subscribe(userID uint) chan liveEvent {
	ch := make(chan liveEvent, 16)
	h.mu.Lock()
	h.subs[ch] = userID
	h.mu.Unlock()
	return ch
}

func (h *eventHub) unsubscribe(ch chan liveEvent) {
	h.mu.Lock()
	delete(h.subs, ch)
	h.mu.Unlock()
	close(ch)
}

// Broadcast sends an event to every connected client. Slow clients are
// skipped rather than blocking the publisher.
func Broadcast(name string, payload any) {
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	ev := liveEvent{Name: name, Data: data}
	hub.mu.RLock()
	defer hub.mu.RUnlock()
	for ch := range hub.subs {
		select {
		case ch <- ev:
		default:
		}
	}
}

// GET /events — SSE stream.
func StreamEvents(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	ch := hub.subscribe(userID)
	defer hub.unsubscribe(ch)

	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no") // tell nginx not to buffer the stream

	// Tell the client how long to wait before reconnecting, and say hello.
	fmt.Fprintf(c.Writer, "retry: 3000\nevent: hello\ndata: {\"at\":%q}\n\n", time.Now().Format(time.RFC3339))
	c.Writer.Flush()

	heartbeat := time.NewTicker(25 * time.Second)
	defer heartbeat.Stop()

	c.Stream(func(w io.Writer) bool {
		select {
		case <-c.Request.Context().Done():
			return false
		case ev, ok := <-ch:
			if !ok {
				return false
			}
			fmt.Fprintf(w, "event: %s\ndata: %s\n\n", ev.Name, ev.Data)
			return true
		case <-heartbeat.C:
			// Comment line keeps proxies and mobile networks from closing the connection.
			fmt.Fprint(w, ": ping\n\n")
			return true
		}
	})
}
