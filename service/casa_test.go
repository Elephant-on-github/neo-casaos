package service

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"testing"

	"github.com/tidwall/gjson"

	"github.com/IceWhaleTech/CasaOS/common"
)

func TestGetCasaosVersionFromVersionJSON(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"data":{"version":"9.9.9","change_log":"notes"}}`)
	}))
	defer ts.Close()

	old := versionJSONURL
	versionJSONURL = ts.URL
	defer func() { versionJSONURL = old }()
	Cache.Delete("casa_version")

	got := NewCasaService().GetCasaosVersion()
	if got.Version != "9.9.9" {
		t.Fatalf("Version = %q, want 9.9.9", got.Version)
	}
	if got.ChangeLog != "notes" {
		t.Fatalf("ChangeLog = %q, want notes", got.ChangeLog)
	}
}

func TestGetCasaosVersionUnreachable(t *testing.T) {
	old := versionJSONURL
	versionJSONURL = "http://127.0.0.1:1" // closed port
	defer func() { versionJSONURL = old }()
	Cache.Delete("casa_version")

	got := NewCasaService().GetCasaosVersion()
	if got.Version != "" {
		t.Fatalf("Version = %q, want empty on fetch failure", got.Version)
	}
}

func TestVersionJSONMatchesCommonVERSION(t *testing.T) {
	b, err := os.ReadFile("../../version.json")
	if err != nil {
		t.Fatal(err)
	}
	v := gjson.GetBytes(b, "data.version").String()
	if v != common.VERSION {
		t.Fatalf("version.json data.version = %q, common.VERSION = %q — bump both in the same commit", v, common.VERSION)
	}
	if !regexp.MustCompile(`^\d+\.\d+\.\d+$`).MatchString(v) {
		t.Fatalf("version %q must be numeric X.Y.Z only — the comparator parses segments with Atoi", v)
	}
}
