package model

import "time"

type ComponentVersion struct {
	Version string `json:"version"`
}

type Version struct {
	Id         uint                      `gorm:"column:id;primary_key" json:"id"`
	ChangeLog  string                    `json:"change_log"`
	Version    string                    `json:"version"`
	Components map[string]ComponentVersion `json:"components"`
	CreatedAt  time.Time                 `json:"created_at"`
	UpdatedAt  time.Time                 `json:"updated_at"`
}