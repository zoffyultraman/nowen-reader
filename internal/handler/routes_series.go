package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/middleware"
)

func registerSeriesRoutes(api *gin.RouterGroup) {
	handler := NewSeriesHandler()
	series := api.Group("/series")
	series.Use(middleware.AuthRequired())
	{
		series.GET("", handler.List)
		series.GET("/preview", handler.Preview)
		series.POST("/rebuild", handler.Rebuild)
		series.GET("/:id", handler.Get)
		series.PUT("/:id", handler.Update)
		series.PUT("/:id/structure", handler.UpdateStructure)
		series.POST("/:id/re-detect", handler.Redetect)
		series.DELETE("/:id", handler.Delete)
	}
}
