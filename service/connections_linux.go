//go:build linux

package service

import (
	"fmt"

	"github.com/moby/sys/mount"
	"golang.org/x/sys/unix"
)

func (s *connectionsStruct) MountSmaba(username, host, directory, port, mountPoint, password string) error {
	err := unix.Mount(
		fmt.Sprintf("//%s/%s", host, directory),
		mountPoint,
		"cifs",
		unix.MS_NOATIME|unix.MS_NODEV|unix.MS_NOSUID,
		fmt.Sprintf("username=%s,password=%s", username, password),
	)
	return err
}

func (s *connectionsStruct) UnmountSmaba(mountPoint string) error {
	return mount.Unmount(mountPoint)
}
