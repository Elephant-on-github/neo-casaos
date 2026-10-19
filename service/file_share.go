package service

import (
	"crypto/rand"
	"encoding/base64"
	"time"

	"github.com/IceWhaleTech/CasaOS/service/model"
	"gorm.io/gorm"
)

type FileShareService interface {
	CreateShare(path string, expireSeconds int64) (model.FileShareDBModel, error)
	GetShareByToken(token string) (model.FileShareDBModel, error)
	ListShares() ([]model.FileShareDBModel, error)
	DeleteShare(id uint) error
}

type fileShareStruct struct {
	db *gorm.DB
}

func NewFileShareService(db *gorm.DB) FileShareService {
	return &fileShareStruct{db: db}
}

func (s *fileShareStruct) CreateShare(path string, expireSeconds int64) (model.FileShareDBModel, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return model.FileShareDBModel{}, err
	}
	share := model.FileShareDBModel{
		Token: base64.RawURLEncoding.EncodeToString(b),
		Path:  path,
	}
	if expireSeconds > 0 {
		share.ExpireAt = time.Now().Unix() + expireSeconds
	}
	if err := s.db.Create(&share).Error; err != nil {
		return model.FileShareDBModel{}, err
	}
	return share, nil
}

func (s *fileShareStruct) GetShareByToken(token string) (model.FileShareDBModel, error) {
	var share model.FileShareDBModel
	if err := s.db.Where("token = ?", token).First(&share).Error; err != nil {
		return model.FileShareDBModel{}, err
	}
	return share, nil
}

func (s *fileShareStruct) ListShares() ([]model.FileShareDBModel, error) {
	var shares []model.FileShareDBModel
	if err := s.db.Find(&shares).Error; err != nil {
		return nil, err
	}
	return shares, nil
}

func (s *fileShareStruct) DeleteShare(id uint) error {
	return s.db.Where("id = ?", id).Delete(&model.FileShareDBModel{}).Error
}
