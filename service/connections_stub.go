//go:build !linux

package service

import "fmt"

func (s *connectionsStruct) MountSmaba(username, host, directory, port, mountPoint, password string) error {
	return fmt.Errorf("Samba mount is not supported on this platform")
}

func (s *connectionsStruct) UnmountSmaba(mountPoint string) error {
	return fmt.Errorf("Samba unmount is not supported on this platform")
}
