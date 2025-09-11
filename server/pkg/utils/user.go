package utils

import (
	"github.com/ente-io/museum/ente"
	"github.com/ente-io/museum/pkg/repo"
	"github.com/ente-io/museum/pkg/utils/crypto"
	"github.com/ente-io/stacktrace"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

type User struct {
	UserRepo   *repo.UserRepository
	HashingKey []byte
}

func (c *User) GetUserID(upUsername string) (int64, string, error) {
	var err error
	var emailHash string
	var user ente.User
	emailHash, err = crypto.GetHash(upUsername, c.HashingKey)
	log.Infof("reqBody.Username: %s", upUsername)
	if err != nil {
		return 0, "", stacktrace.Propagate(err, "failed to hash username")
	}
	user, err = c.UserRepo.GetUserByEmailHash(emailHash)

	if err != nil {
		err = nil
		// If user not found, try with email format (username@domain)
		log.Infof("user not found c.UserRepo.GetUserByEmailHash(emailHash): %s", err)

		upUsername = upUsername + "@" + viper.GetString("unplugged.email-host")
		emailHash, err = crypto.GetHash(upUsername, c.HashingKey)
		if err != nil {
			return 0, "", stacktrace.Propagate(err, "failed to hash email username")
		}
		user, err = c.UserRepo.GetUserByEmailHash(emailHash)
		if err != nil {
			log.Errorf("emailUser not found c.UserRepo.GetUserByEmailHash(emailHashAlt): %s", err)
			return 0, "", stacktrace.Propagate(err, "failed to get user by emailUser hash")
		}
	}
	log.Infof("user found c.UserRepo.GetUserByEmailHash(emailHash): %s, %s", user.ID, upUsername)
	return user.ID, upUsername, nil
}
