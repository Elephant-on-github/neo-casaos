package service

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/glebarez/sqlite"
	"github.com/IceWhaleTech/CasaOS/service/model"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func newFileShareTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "test.db")), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() {
		if sqlDB, err := db.DB(); err == nil {
			sqlDB.Close()
		}
	})
	if err := db.AutoMigrate(&model.FileShareDBModel{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestFileShareService(t *testing.T) {
	s := NewFileShareService(newFileShareTestDB(t))

	// create without expiry
	share, err := s.CreateShare("/tmp/testfile.txt", 0)
	if err != nil {
		t.Fatalf("CreateShare: %v", err)
	}
	if share.Token == "" {
		t.Fatal("expected non-empty token")
	}
	if share.ExpireAt != 0 {
		t.Fatalf("expected no expiry (0), got %d", share.ExpireAt)
	}

	// tokens are unique
	other, err := s.CreateShare("/tmp/other.txt", 0)
	if err != nil {
		t.Fatalf("CreateShare(other): %v", err)
	}
	if other.Token == share.Token {
		t.Fatal("expected unique tokens")
	}

	// get-by-token round-trips the path
	got, err := s.GetShareByToken(share.Token)
	if err != nil {
		t.Fatalf("GetShareByToken: %v", err)
	}
	if got.Path != "/tmp/testfile.txt" {
		t.Fatalf("expected path round-trip, got %q", got.Path)
	}

	// unknown token errors
	if _, err := s.GetShareByToken("nope"); err == nil {
		t.Fatal("expected error for unknown token")
	}

	// create with expiry sets a future ExpireAt
	exp, err := s.CreateShare("/tmp/expiring.txt", 3600)
	if err != nil {
		t.Fatalf("CreateShare(expiring): %v", err)
	}
	if exp.ExpireAt <= time.Now().Unix() {
		t.Fatalf("expected future expiry, got %d", exp.ExpireAt)
	}

	// list returns all shares
	shares, err := s.ListShares()
	if err != nil {
		t.Fatalf("ListShares: %v", err)
	}
	if len(shares) != 3 {
		t.Fatalf("expected 3 shares, got %d", len(shares))
	}

	// delete removes the share
	if err := s.DeleteShare(share.ID); err != nil {
		t.Fatalf("DeleteShare: %v", err)
	}
	if _, err := s.GetShareByToken(share.Token); err == nil {
		t.Fatal("expected error after delete")
	}
}
