package model

// FileShareDBModel represents a public share link for a single file.
// A share maps an unguessable token to an absolute file path, optionally with an
// expiry (unix seconds; 0 means the link never expires).
type FileShareDBModel struct {
	ID       uint   `gorm:"column:id;primary_key" json:"id"`
	Token    string `gorm:"column:token;uniqueIndex" json:"token"`
	Path     string `gorm:"column:path" json:"path"`
	ExpireAt int64  `gorm:"column:expire_at" json:"expire_at"`
	Created  int64  `gorm:"autoCreateTime" json:"created"`
}

func (p *FileShareDBModel) TableName() string {
	return "o_file_share"
}
