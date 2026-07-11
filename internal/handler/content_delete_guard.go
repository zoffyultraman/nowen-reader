package handler

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// recordOnlySingleDeleteGuard records the source identity before a single
// record-only deletion. The scanner insert trigger then keeps the on-disk file
// hidden instead of adding it back on the next automatic scan.
func recordOnlySingleDeleteGuard() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Query("deleteFiles") == "true" {
			c.Next()
			return
		}

		identities, err := store.GetComicSourceIdentities([]string{c.Param("id")})
		if err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Failed to preserve record-only deletion"})
			return
		}
		if err := store.AddIgnoredLibraryContents(identities); err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Failed to preserve record-only deletion"})
			return
		}

		c.Next()
		if c.Writer.Status() >= http.StatusBadRequest {
			if err := store.RemoveIgnoredLibraryContents(identities); err != nil {
				log.Printf("[delete-guard] failed to roll back single delete tombstone: %v", err)
			}
		}
	}
}

// recordOnlyBatchDeleteGuard applies the same behavior to batch delete calls
// while restoring the request body for the existing batch handler.
func recordOnlyBatchDeleteGuard() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Body == nil {
			c.Next()
			return
		}

		body, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
			return
		}
		c.Request.Body = io.NopCloser(bytes.NewReader(body))

		var payload struct {
			Action      string   `json:"action"`
			ComicIDs    []string `json:"comicIds"`
			DeleteFiles bool     `json:"deleteFiles"`
		}
		if json.Unmarshal(body, &payload) != nil || payload.Action != "delete" || payload.DeleteFiles || len(payload.ComicIDs) == 0 {
			c.Next()
			return
		}

		identities, err := store.GetComicSourceIdentities(payload.ComicIDs)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Failed to preserve record-only deletion"})
			return
		}
		if err := store.AddIgnoredLibraryContents(identities); err != nil {
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "Failed to preserve record-only deletion"})
			return
		}

		c.Next()
		if c.Writer.Status() >= http.StatusBadRequest {
			if err := store.RemoveIgnoredLibraryContents(identities); err != nil {
				log.Printf("[delete-guard] failed to roll back batch delete tombstones: %v", err)
			}
		}
	}
}
