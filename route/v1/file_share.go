package v1

import (
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/IceWhaleTech/CasaOS/model"
	"github.com/IceWhaleTech/CasaOS/pkg/utils/common_err"
	"github.com/IceWhaleTech/CasaOS/pkg/utils/file"
	"github.com/IceWhaleTech/CasaOS/service"
	"github.com/labstack/echo/v4"
)

type createFileShareRequest struct {
	Path          string `json:"path"`
	ExpireSeconds int64  `json:"expire_seconds"`
}

// PostCreateFileShare creates a shareable link for a file. Authenticated.
func PostCreateFileShare(ctx echo.Context) error {
	req := createFileShareRequest{}
	if err := ctx.Bind(&req); err != nil {
		return ctx.JSON(common_err.CLIENT_ERROR, model.Result{Success: common_err.CLIENT_ERROR, Message: common_err.GetMsg(common_err.CLIENT_ERROR)})
	}
	if req.Path == "" {
		return ctx.JSON(common_err.INVALID_PARAMS, model.Result{Success: common_err.INVALID_PARAMS, Message: common_err.GetMsg(common_err.INVALID_PARAMS), Data: "path is required"})
	}
	info, err := os.Stat(req.Path)
	if err != nil {
		return ctx.JSON(common_err.FILE_DOES_NOT_EXIST, model.Result{Success: common_err.FILE_DOES_NOT_EXIST, Message: common_err.GetMsg(common_err.FILE_DOES_NOT_EXIST)})
	}
	if info.IsDir() {
		return ctx.JSON(common_err.CLIENT_ERROR, model.Result{Success: common_err.CLIENT_ERROR, Message: common_err.GetMsg(common_err.CLIENT_ERROR), Data: "cannot share a directory"})
	}
	share, err := service.MyService.FileShare().CreateShare(req.Path, req.ExpireSeconds)
	if err != nil {
		return ctx.JSON(common_err.SERVICE_ERROR, model.Result{Success: common_err.SERVICE_ERROR, Message: common_err.GetMsg(common_err.SERVICE_ERROR)})
	}
	return ctx.JSON(common_err.SUCCESS, model.Result{Success: common_err.SUCCESS, Message: common_err.GetMsg(common_err.SUCCESS),
		Data: map[string]string{"token": share.Token, "url": "/v1/file/share/" + share.Token}})
}

// GetPublicFileShare resolves a share token and serves the file. Public (no auth).
func GetPublicFileShare(ctx echo.Context) error {
	share, err := service.MyService.FileShare().GetShareByToken(ctx.Param("token"))
	if err != nil {
		return ctx.JSON(common_err.FILE_DOES_NOT_EXIST, model.Result{Success: common_err.FILE_DOES_NOT_EXIST, Message: common_err.GetMsg(common_err.FILE_DOES_NOT_EXIST)})
	}
	if share.ExpireAt > 0 && time.Now().Unix() > share.ExpireAt {
		return ctx.JSON(common_err.CLIENT_ERROR, model.Result{Success: common_err.CLIENT_ERROR, Message: "link expired"})
	}
	if !file.Exists(share.Path) {
		return ctx.JSON(common_err.FILE_DOES_NOT_EXIST, model.Result{Success: common_err.FILE_DOES_NOT_EXIST, Message: common_err.GetMsg(common_err.FILE_DOES_NOT_EXIST)})
	}
	ctx.Response().Header().Set("Content-Disposition", "attachment; filename*=utf-8''"+url.QueryEscape(filepath.Base(share.Path)))
	http.ServeFile(ctx.Response(), ctx.Request(), share.Path)
	return nil
}

// DeleteFileShare revokes a share by id (query param). Authenticated.
func DeleteFileShare(ctx echo.Context) error {
	id, err := strconv.ParseUint(ctx.QueryParam("id"), 10, 64)
	if err != nil {
		return ctx.JSON(common_err.INVALID_PARAMS, model.Result{Success: common_err.INVALID_PARAMS, Message: common_err.GetMsg(common_err.INVALID_PARAMS)})
	}
	if err := service.MyService.FileShare().DeleteShare(uint(id)); err != nil {
		return ctx.JSON(common_err.SERVICE_ERROR, model.Result{Success: common_err.SERVICE_ERROR, Message: common_err.GetMsg(common_err.SERVICE_ERROR)})
	}
	return ctx.JSON(common_err.SUCCESS, model.Result{Success: common_err.SUCCESS, Message: common_err.GetMsg(common_err.SUCCESS)})
}

// ListFileShares lists all share links. Authenticated.
func ListFileShares(ctx echo.Context) error {
	shares, err := service.MyService.FileShare().ListShares()
	if err != nil {
		return ctx.JSON(common_err.SERVICE_ERROR, model.Result{Success: common_err.SERVICE_ERROR, Message: common_err.GetMsg(common_err.SERVICE_ERROR)})
	}
	return ctx.JSON(common_err.SUCCESS, model.Result{Success: common_err.SUCCESS, Message: common_err.GetMsg(common_err.SUCCESS), Data: shares})
}
