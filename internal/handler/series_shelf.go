package handler

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

type bufferedResponseWriter struct {
	gin.ResponseWriter
	body   bytes.Buffer
	status int
}

func (w *bufferedResponseWriter) WriteHeader(code int) { w.status = code }
func (w *bufferedResponseWriter) WriteHeaderNow()      {}
func (w *bufferedResponseWriter) Status() int          { return w.status }
func (w *bufferedResponseWriter) Size() int            { return w.body.Len() }
func (w *bufferedResponseWriter) Written() bool        { return w.body.Len() > 0 }
func (w *bufferedResponseWriter) Write(data []byte) (int, error) {
	if w.status == 0 {
		w.status = http.StatusOK
	}
	return w.body.Write(data)
}
func (w *bufferedResponseWriter) WriteString(value string) (int, error) {
	if w.status == 0 {
		w.status = http.StatusOK
	}
	return w.body.WriteString(value)
}

// collapseSeriesShelf turns the flat comic response into a shelf response only
// when the web client explicitly asks for seriesView=true. Other API clients
// continue receiving ordinary Comic rows.
func collapseSeriesShelf() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Query("seriesView") != "true" {
			c.Next()
			return
		}
		if err := service.EnsureComicSeriesFresh(); err != nil {
			log.Printf("[series] refresh before shelf failed: %v", err)
		}

		original := c.Writer
		buffered := &bufferedResponseWriter{ResponseWriter: original, status: http.StatusOK}
		c.Writer = buffered
		c.Next()
		c.Writer = original

		status := buffered.status
		payload := buffered.body.Bytes()
		if status == http.StatusOK {
			var result store.ComicListResult
			if err := json.Unmarshal(payload, &result); err == nil {
				if collapsed, err := store.CollapseComicListIntoSeries(result.Comics, getUserID(c)); err == nil {
					result.Comics = collapsed
					result.Total = len(collapsed)
					result.Page = 1
					result.PageSize = len(collapsed)
					result.TotalPages = 1
					if encoded, marshalErr := json.Marshal(result); marshalErr == nil {
						payload = encoded
					}
				} else {
					log.Printf("[series] collapse shelf failed: %v", err)
				}
			}
		}

		original.Header().Del("Content-Length")
		original.WriteHeader(status)
		_, _ = original.Write(payload)
	}
}
