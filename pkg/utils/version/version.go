/*
 * @Author: LinkLeong link@icewhale.com
 * @Date: 2022-05-13 18:15:46
 * @LastEditors: LinkLeong
 * @LastEditTime: 2022-07-21 15:27:53
 * @FilePath: /CasaOS/pkg/utils/version/version.go
 * @Description:
 * @Website: https://www.casaos.io
 * Copyright (c) 2022 by icewhale, All Rights Reserved.
 */
package version

import (
	"strconv"
	"strings"

	"github.com/IceWhaleTech/CasaOS/common"
	"github.com/IceWhaleTech/CasaOS/model"
)

// IsNeedUpdateBool reports whether `latest` is newer than `installed`.
// Empty `installed` (unknown) is treated as "needs update".
func IsNeedUpdateBool(installed, latest string) bool {
	if installed == "" {
		return latest != ""
	}
	if latest == "" {
		return false
	}
	v1 := strings.Split(installed, ".")
	v2 := strings.Split(latest, ".")

	for len(v1) < len(v2) {
		v1 = append(v1, "0")
	}
	for len(v2) < len(v1) {
		v2 = append(v2, "0")
	}
	for i := 0; i < len(v1); i++ {
		a, _ := strconv.Atoi(v1[i])
		b, _ := strconv.Atoi(v2[i])
		if b > a {
			return true
		}
		if b < a {
			return false
		}
	}
	return false
}

func IsNeedUpdate(version model.Version) (bool, model.Version) {

	v1 := strings.Split(version.Version, ".")

	v2 := strings.Split(common.VERSION, ".")

	for len(v1) < len(v2) {
		v1 = append(v1, "0")
	}
	for len(v2) < len(v1) {
		v2 = append(v2, "0")
	}
	for i := 0; i < len(v1); i++ {
		a, _ := strconv.Atoi(v1[i])
		b, _ := strconv.Atoi(v2[i])
		if a > b {
			return true, version
		}
		if a < b {
			return false, version
		}
	}
	return false, version
}
