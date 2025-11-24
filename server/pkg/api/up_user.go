package api

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/ente-io/museum/pkg/controller"
	"github.com/ente-io/museum/pkg/middleware"
	"github.com/gin-contrib/requestid"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"

	"github.com/ente-io/museum/ente"
	"github.com/ente-io/museum/pkg/controller/user"
	"github.com/ente-io/museum/pkg/utils/auth"
	"github.com/ente-io/museum/pkg/utils/crypto"
	"github.com/ente-io/museum/pkg/utils/handler"
	"github.com/ente-io/stacktrace"
	"github.com/gin-gonic/gin"
)

// UPUserHandler handles user-related requests for the UP API
type UPUserHandler struct {
	UserController      *user.UserController
	JWTValidator        *auth.JWTValidator
	UPBillingController *controller.UPBillingController
	UPStoreController   *controller.UPStoreController
}

// SendOTT validates the JWT token and then calls the original SendOTT method
func (h *UPUserHandler) SendOTT(c *gin.Context) {

	var request ente.SendOTTRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		handler.Error(c, stacktrace.Propagate(err, ""))
		return
	}

	userID, err := strconv.ParseInt(c.Request.Header.Get(middleware.AuthUserID), 10, 64)
	if userID != 0 && request.Purpose == ente.SignUpOTTPurpose {
		log.Warningf("SendOTT Trying to send OTT for logged userID %s, email %s",
			userID, c.Request.Header.Get(middleware.UpUsernameHeader))
		handler.Error(c, stacktrace.Propagate(ente.ErrUserAlreadyRegistered, "user has already completed sign up process"))
		return
	}
	// Validate JWT token
	authToken := c.GetHeader("Authorization")

	log.Infof("SendOTT, Sending OTT for %s", request.Purpose)
	preferredUsername, _ := h.JWTValidator.GetPreferredUsername(authToken)
	username, isError := buildEmailFromUsername(c, preferredUsername)
	if isError {
		return
	}

	if request.Purpose == ente.SignUpOTTPurpose || request.Purpose == ente.LoginOTTPurpose {
		err := h.UserController.SendEmailOTT(c, username, request.Purpose, request.Mobile)
		if err != nil {
			if strings.Contains(err.Error(), "user has not completed sign up process") {
				logger := log.WithFields(log.Fields{
					"user_id":    userID,
					"user_email": username,
					"req_id":     requestid.Get(c),
					"req_ctx":    "account_deletion",
				})
				_, err := h.UserController.HandleAccountDeletion(c, userID, logger)
				if err != nil {
					handler.Error(c, stacktrace.Propagate(err, ""))
					return
				}
			}
		}
	} else {
		log.Errorf("Current OTT Purpose: %s. It must be %s", request.Purpose, ente.SignUpOTTPurpose)
		handler.Error(c, stacktrace.Propagate(ente.ErrBadRequest, "Invalid OTT purpose"))
		return
	}

	source := "UP Store"

	usernameHash, _ := crypto.GetHash(username, h.UserController.HashingKey)
	app := auth.GetApp(c)
	otts, _ := h.UserController.UserAuthRepo.GetValidOTTs(usernameHash, app)
	if len(otts) > 0 {
		err := h.UserController.UserAuthRepo.RemoveOTT(usernameHash, otts[0], app)
		if err != nil {

			return
		}
	}
	response, err := h.UserController.OnVerificationSuccess(c, username, &source)
	if err != nil {
		handler.Error(c, stacktrace.Propagate(err, "h.UserController.OnVerificationSuccess failed"))
		return
	}
	_, err = h.UPBillingController.UPVerifySubscription(response.ID)
	if err != nil {
		handler.Error(c, stacktrace.Propagate(err, "h.UPBillingController.UPVerifySubscription(response.ID) failed"))
		return
	}
	c.JSON(http.StatusOK, response)

}

func buildEmailFromUsername(c *gin.Context, preferredUsername string) (string, bool) {
	var emailHost = viper.GetString("unplugged.email-host")
	username := preferredUsername + "@" + emailHost
	log.Infof("OTT Username: %s", username)
	if len(username) == 0 {
		handler.Error(c, stacktrace.Propagate(ente.ErrBadRequest, "Email id is missing"))
		return "", true
	}
	return username, false
}
