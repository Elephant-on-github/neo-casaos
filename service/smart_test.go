/*
 * @Author: neo
 * @Description: Tests for SMART parsing.
 */
package service

import "testing"

func TestParseSmartctlPassed(t *testing.T) {
	out := []byte(`{
		"model_name": "Samsung SSD 870",
		"serial_number": "S1234",
		"user_capacity": {"bytes": 1000204886016},
		"temperature": {"current": 34},
		"power_on_time": {"hours": 1234},
		"smart_status": {"passed": true}
	}`)
	info := parseSmartctl("/dev/sda", out)
	if info.Health != "PASSED" {
		t.Errorf("Health = %q, want PASSED", info.Health)
	}
	if !info.SmartSupported {
		t.Error("SmartSupported = false, want true")
	}
	if info.Model != "Samsung SSD 870" || info.Serial != "S1234" {
		t.Errorf("Model/Serial wrong: %+v", info)
	}
	if info.Temperature != 34 || info.PowerOnHours != 1234 {
		t.Errorf("Temperature/PowerOnHours wrong: %+v", info)
	}
	if info.Capacity != 1000204886016 {
		t.Errorf("Capacity = %d, want 1000204886016", info.Capacity)
	}
	if info.Device != "/dev/sda" {
		t.Errorf("Device = %q, want /dev/sda", info.Device)
	}
}

func TestParseSmartctlFailed(t *testing.T) {
	out := []byte(`{"model_name":"WDC WD10EZEX","smart_status":{"passed":false}}`)
	info := parseSmartctl("/dev/sdb", out)
	if info.Health != "FAILED" {
		t.Errorf("Health = %q, want FAILED", info.Health)
	}
}

func TestParseSmartctlNoVerdict(t *testing.T) {
	// device answered, but no smart_status key (USB bridge)
	out := []byte(`{"model_name":"Some USB Bridge","temperature":{"current":40}}`)
	info := parseSmartctl("/dev/sdc", out)
	if info.Health != "UNKNOWN" {
		t.Errorf("Health = %q, want UNKNOWN", info.Health)
	}
	if !info.SmartSupported {
		t.Error("SmartSupported = false, want true when device answered")
	}
	if info.Temperature != 40 {
		t.Errorf("Temperature = %d, want 40", info.Temperature)
	}
}

func TestParseSmartctlGarbage(t *testing.T) {
	info := parseSmartctl("/dev/sdd", []byte("not json at all"))
	if info.Health != "UNKNOWN" {
		t.Errorf("Health = %q, want UNKNOWN for unparseable output", info.Health)
	}
	if info.SmartSupported {
		t.Error("SmartSupported = true, want false for unparseable output")
	}
}

func TestIsSmartCapable(t *testing.T) {
	capable := []string{"sda", "nvme0n1", "mmcblk0", "vda", "hda"}
	// NOTE: "sda1" (partitions) also passes the prefix filter, but /sys/block
	// only ever contains whole disks so the filter never sees them.
	notCapable := []string{"loop0", "ram0", "zram0", "dm-0", "md0", "sr0"}
	for _, n := range capable {
		if !isSmartCapable(n) {
			t.Errorf("isSmartCapable(%q) = false, want true", n)
		}
	}
	for _, n := range notCapable {
		if isSmartCapable(n) {
			t.Errorf("isSmartCapable(%q) = true, want false", n)
		}
	}
}
