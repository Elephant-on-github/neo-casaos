/*
 * @Author: neo
 * @Description: Drive health (SMART) + temperature via smartctl (smartmontools).
 */
package service

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"strings"
	"time"
)

// SMARTInfo is the parsed health snapshot for a single physical drive.
type SMARTInfo struct {
	Device         string `json:"device"`
	Model          string `json:"model"`
	Serial         string `json:"serial"`
	Capacity       uint64 `json:"capacity"`       // bytes
	Health         string `json:"health"`         // PASSED | FAILED | UNKNOWN
	Temperature    int    `json:"temperature"`    // celsius, 0 if unknown
	PowerOnHours   int    `json:"power_on_hours"` // 0 if unknown
	SmartSupported bool   `json:"smart_supported"`
}

// smartctlRaw mirrors the subset of `smartctl --json --all` we care about.
type smartctlRaw struct {
	ModelName    string `json:"model_name"`
	SerialNumber string `json:"serial_number"`
	UserCapacity struct {
		Bytes uint64 `json:"bytes"`
	} `json:"user_capacity"`
	Temperature struct {
		Current int `json:"current"`
	} `json:"temperature"`
	PowerOnTime struct {
		Hours int `json:"hours"`
	} `json:"power_on_time"`
	// *bool: nil = key absent (SMART unsupported), true/false = actual verdict.
	SmartStatus struct {
		Passed *bool `json:"passed"`
	} `json:"smart_status"`
}

// isSmartCapable filters /sys/block entries to real storage devices that
// smartctl could talk to (skips loop, ram, zram, md, dm, sr, etc).
func isSmartCapable(name string) bool {
	for _, p := range []string{"sd", "hd", "nvme", "mmcblk", "vd", "xvd", "ubd"} {
		if strings.HasPrefix(name, p) {
			return true
		}
	}
	return false
}

// listBlockDevices returns whole-disk kernel names (e.g. sda, nvme0n1).
// /sys/block only ever contains whole disks, never partitions.
func listBlockDevices() []string {
	entries, err := os.ReadDir("/sys/block")
	if err != nil {
		return nil
	}
	var devs []string
	for _, e := range entries {
		if isSmartCapable(e.Name()) {
			devs = append(devs, e.Name())
		}
	}
	return devs
}

// GetSMARTInfo enumerates physical drives and runs smartctl on each.
// Returns one SMARTInfo per drive; drives without a smartctl binary or that
// error out are reported with Health "UNKNOWN" so the UI can still list them.
func (s *systemService) GetSMARTInfo() []SMARTInfo {
	devs := listBlockDevices()
	result := make([]SMARTInfo, 0, len(devs))

	if _, err := exec.LookPath("smartctl"); err != nil {
		// smartctl not installed — report devices as UNKNOWN, don't fail hard.
		for _, d := range devs {
			result = append(result, SMARTInfo{Device: "/dev/" + d, Health: "UNKNOWN"})
		}
		return result
	}

	for _, d := range devs {
		// Per-drive deadline: a hung USB bridge must not block the endpoint
		// for minutes; a timed-out drive is reported as UNKNOWN.
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		out, err := exec.CommandContext(ctx, "smartctl", "--json", "--all", "/dev/"+d).Output()
		cancel()
		// smartctl exits non-zero for many benign reasons but still prints JSON
		// on stdout; only fall back to stderr when stdout was empty.
		if err != nil && len(out) == 0 {
			if exitErr, ok := err.(*exec.ExitError); ok {
				out = exitErr.Stderr
			}
		}
		result = append(result, parseSmartctl("/dev/"+d, out))
	}
	return result
}

// parseSmartctl maps smartctl JSON output to a SMARTInfo. Unparseable output
// yields an UNKNOWN entry so the device is still listed.
func parseSmartctl(device string, out []byte) SMARTInfo {
	info := SMARTInfo{Device: device, Health: "UNKNOWN"}
	var raw smartctlRaw
	if jsonErr := json.Unmarshal(out, &raw); jsonErr != nil {
		return info
	}
	info.Model = raw.ModelName
	info.Serial = raw.SerialNumber
	info.Capacity = raw.UserCapacity.Bytes
	info.Temperature = raw.Temperature.Current
	info.PowerOnHours = raw.PowerOnTime.Hours
	if raw.SmartStatus.Passed != nil {
		info.SmartSupported = true
		if *raw.SmartStatus.Passed {
			info.Health = "PASSED"
		} else {
			info.Health = "FAILED"
		}
	} else if raw.ModelName != "" {
		// Device answered but no health verdict (some USB bridges/NVMe
		// layouts) — SMART present, verdict unavailable.
		info.SmartSupported = true
	}
	return info
}
