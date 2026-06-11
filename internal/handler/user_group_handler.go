package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

// UserGroupHandler handles user group management API endpoints.
type UserGroupHandler struct{}

// NewUserGroupHandler creates a new UserGroupHandler.
func NewUserGroupHandler() *UserGroupHandler {
	return &UserGroupHandler{}
}

// ============================================================
// GET /api/admin/user-groups — List all user groups
// ============================================================

func (h *UserGroupHandler) ListGroups(c *gin.Context) {
	groups, err := store.GetAllUserGroups()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user groups"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"groups": groups})
}

// ============================================================
// POST /api/admin/user-groups — Create user group
// ============================================================

func (h *UserGroupHandler) CreateGroup(c *gin.Context) {
	var req struct {
		Name        string `json:"name" binding:"required"`
		Description string `json:"description"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	group := &model.UserGroup{
		Name:        req.Name,
		Description: req.Description,
	}

	if err := store.CreateUserGroup(group); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user group"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"group": group})
}

// ============================================================
// PUT /api/admin/user-groups/:id — Update user group
// ============================================================

func (h *UserGroupHandler) UpdateGroup(c *gin.Context) {
	id := c.Param("id")

	existing, err := store.GetUserGroupByID(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user group"})
		return
	}
	if existing == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User group not found"})
		return
	}

	var req struct {
		Name        *string `json:"name"`
		Description *string `json:"description"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Description != nil {
		existing.Description = *req.Description
	}

	if err := store.UpdateUserGroup(existing); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user group"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"group": existing})
}

// ============================================================
// DELETE /api/admin/user-groups/:id — Delete user group
// ============================================================

func (h *UserGroupHandler) DeleteGroup(c *gin.Context) {
	id := c.Param("id")

	existing, err := store.GetUserGroupByID(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user group"})
		return
	}
	if existing == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User group not found"})
		return
	}

	if err := store.DeleteUserGroup(id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user group"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// ============================================================
// GET /api/admin/user-groups/:id/members — Get group members
// ============================================================

func (h *UserGroupHandler) GetMembers(c *gin.Context) {
	groupID := c.Param("id")

	existing, err := store.GetUserGroupByID(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user group"})
		return
	}
	if existing == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User group not found"})
		return
	}

	members, err := store.GetGroupMembers(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch group members"})
		return
	}

	// Get all users for selection
	allUsers, err := store.ListUsers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
		return
	}

	// Build member ID set
	memberIDs := make(map[string]bool)
	for _, m := range members {
		memberIDs[m.ID] = true
	}

	type userWithMembership struct {
		model.AuthUser
		IsMember bool `json:"isMember"`
	}

	users := make([]userWithMembership, len(allUsers))
	for i, u := range allUsers {
		users[i] = userWithMembership{
			AuthUser: u,
			IsMember: memberIDs[u.ID],
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"groupId": groupID,
		"members": members,
		"users":   users,
	})
}

// ============================================================
// PUT /api/admin/user-groups/:id/members — Set group members
// ============================================================

func (h *UserGroupHandler) SetMembers(c *gin.Context) {
	groupID := c.Param("id")

	existing, err := store.GetUserGroupByID(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user group"})
		return
	}
	if existing == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User group not found"})
		return
	}

	var req struct {
		UserIDs []string `json:"userIds"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := store.SetGroupMembers(groupID, req.UserIDs); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update group members"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// ============================================================
// GET /api/admin/user-groups/:id/library-access — Get group library access
// ============================================================

func (h *UserGroupHandler) GetLibraryAccess(c *gin.Context) {
	groupID := c.Param("id")

	existing, err := store.GetUserGroupByID(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user group"})
		return
	}
	if existing == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User group not found"})
		return
	}

	accesses, err := store.GetGroupLibraryAccess(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch library access"})
		return
	}

	// Get all libraries for context
	libraries, err := store.GetAllLibraries()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch libraries"})
		return
	}

	// Build access map
	accessMap := make(map[string]bool)
	for _, a := range accesses {
		accessMap[a.LibraryID] = a.CanView
	}

	type libraryAccess struct {
		model.Library
		CanView bool `json:"canView"`
	}

	result := make([]libraryAccess, len(libraries))
	for i, lib := range libraries {
		result[i] = libraryAccess{
			Library: lib,
			CanView: accessMap[lib.ID],
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"groupId":   groupID,
		"libraries": result,
	})
}

// ============================================================
// PUT /api/admin/user-groups/:id/library-access — Set group library access
// ============================================================

func (h *UserGroupHandler) SetLibraryAccess(c *gin.Context) {
	groupID := c.Param("id")

	existing, err := store.GetUserGroupByID(groupID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user group"})
		return
	}
	if existing == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User group not found"})
		return
	}

	var req struct {
		LibraryIDs []string `json:"libraryIds"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	if err := store.SetGroupLibraryAccess(groupID, req.LibraryIDs); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update group library access"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}
