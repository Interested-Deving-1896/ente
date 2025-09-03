package api

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/ente-io/museum/ente"
	"github.com/ente-io/museum/pkg/utils/auth"
	"github.com/ente-io/museum/pkg/utils/handler"
	"github.com/ente-io/stacktrace"
	"github.com/gin-contrib/requestid"
	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

func (h *AdminHandler) UpDeleteUser(context *gin.Context) {
	var username string
	username = context.Query("username")
	username = strings.TrimSpace(username)
	if username == "" {
		handler.Error(context, stacktrace.Propagate(ente.ErrBadRequest, "email id is missing"))
		return
	}

	userID, username, err := h.UserUtils.GetUserID(username)

	adminID := auth.GetUserID(context.Request.Header)
	logger := logrus.WithFields(logrus.Fields{
		"user_id":    userID,
		"admin_id":   adminID,
		"user_email": username,
		"req_id":     requestid.Get(context),
		"req_ctx":    "account_deletion",
	})

	// todo: (neeraj) refactor this part, currently there's a circular dependency between user and emergency controllers
	removeLegacyErr := h.EmergencyController.HandleAccountDeletion(context, userID, logger)
	if removeLegacyErr != nil {
		handler.Error(context, stacktrace.Propagate(removeLegacyErr, ""))
		return
	}
	response, err := h.UserController.HandleAccountDeletion(context, userID, logger)
	if err != nil {
		handler.Error(context, stacktrace.Propagate(err, ""))
		return
	}
	go h.DiscordController.NotifyAdminAction(
		fmt.Sprintf("Admin (%d) deleting account for %d", adminID, userID))
	context.JSON(http.StatusOK, response)
}
