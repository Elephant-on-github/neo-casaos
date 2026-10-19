package service

import (
	"strings"
	"testing"

	"github.com/IceWhaleTech/CasaOS/service/model"
)

func TestBuildShareConfig(t *testing.T) {
	// anonymous share keeps legacy guest behavior
	anon := buildShareConfig(model.SharesDBModel{Path: "/DATA/pub", Anonymous: true})
	for _, want := range []string{"public = Yes", "guest ok = Yes", "create mask = 0777", "path = /DATA/pub", "force user = root"} {
		if !strings.Contains(anon, want) {
			t.Errorf("anonymous share missing %q:\n%s", want, anon)
		}
	}
	if strings.Contains(anon, "valid users") {
		t.Errorf("anonymous share must not restrict users:\n%s", anon)
	}

	// authenticated share requires the share account, no guest, tighter masks
	auth := buildShareConfig(model.SharesDBModel{Path: "/DATA/priv", Anonymous: false})
	for _, want := range []string{"public = No", "guest ok = No", "valid users = " + ShareUserName, "create mask = 0664", "path = /DATA/priv"} {
		if !strings.Contains(auth, want) {
			t.Errorf("authenticated share missing %q:\n%s", want, auth)
		}
	}
	if strings.Contains(auth, "guest ok = Yes") {
		t.Errorf("authenticated share must not allow guest:\n%s", auth)
	}

	// section name is the base dir, for both kinds
	if !strings.Contains(anon, "[pub]") || !strings.Contains(auth, "[priv]") {
		t.Error("section name must be the base directory name")
	}
}
