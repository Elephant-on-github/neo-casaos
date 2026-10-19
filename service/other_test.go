package service

import (
	"testing"

	"github.com/IceWhaleTech/CasaOS-Common/utils/logger"
	"go.uber.org/goleak"
)

func TestSearch(t *testing.T) {
	logger.LogInitConsoleOnly()
	// CasaOS-Common/external pulls in orca-zhang/ecache, which starts a
	// long-lived janitor goroutine in its package init(). It is an intentional
	// background daemon, not a leak in this test, so ignore it explicitly.
	goleak.VerifyNone(t, goleak.IgnoreAnyFunction("github.com/orca-zhang/ecache.init.0.func1"), goleak.IgnoreAnyFunction("database/sql.(*DB).connectionOpener"))


	if d, e := NewOtherService().Search("test"); e != nil || d == nil {
		t.Error("then test search error", e)
	}
}
