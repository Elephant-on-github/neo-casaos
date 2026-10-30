package service

import (
	json2 "encoding/json"
	"os"
	"time"

	"github.com/IceWhaleTech/CasaOS/model"
	"github.com/IceWhaleTech/CasaOS/pkg/utils/httper"
	"github.com/tidwall/gjson"
)

// installedVersionsPath records which component versions install.sh/update.sh
// put on disk. The backend cannot query the gateway or the (static) UI for
// their running version, so this file is the single source of truth for
// "what is installed".
const installedVersionsPath = "/etc/casaos/installed.json"

type CasaService interface {
	GetCasaosVersion() model.Version
	GetInstalledVersions() map[string]string
}

type casaService struct{}

// versionJSONURL is neo's release channel: version.json on main, bumped with every release.
var versionJSONURL = "https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/version.json"

/**
 * @description: get remote version
 * @return {model.Version}
 */
func (o *casaService) GetCasaosVersion() model.Version {
	keyName := "casa_version"
	var dataStr string
	var version model.Version
	if result, ok := Cache.Get(keyName); ok {
		dataStr, ok = result.(string)
		if ok {
			data := gjson.Get(dataStr, "data")
			json2.Unmarshal([]byte(data.String()), &version)
			return version
		}
	}

	v := httper.Get(versionJSONURL, nil)
	data := gjson.Get(v, "data")
	json2.Unmarshal([]byte(data.String()), &version)

	if len(version.Version) > 0 {
		Cache.Set(keyName, v, time.Minute*20)
	}

	return version
}

// GetInstalledVersions reads the on-disk record written by install.sh/update.sh.
// A missing or unreadable file (legacy installs) yields an empty map, which the
// caller treats as "unknown version -> needs update".
func (o *casaService) GetInstalledVersions() map[string]string {
	out := map[string]string{}
	b, err := os.ReadFile(installedVersionsPath)
	if err != nil {
		return out
	}
	var parsed struct {
		Backend string `json:"backend"`
		Gateway string `json:"gateway"`
		UI      string `json:"ui"`
	}
	if err := json2.Unmarshal(b, &parsed); err != nil {
		return out
	}
	if parsed.Backend != "" {
		out["backend"] = parsed.Backend
	}
	if parsed.Gateway != "" {
		out["gateway"] = parsed.Gateway
	}
	if parsed.UI != "" {
		out["ui"] = parsed.UI
	}
	return out
}

func NewCasaService() CasaService {
	return &casaService{}
}
