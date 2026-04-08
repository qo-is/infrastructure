- Add tests for microvm for:

  - inter-microvm connectivity
  - dependencies between microvms

- systemd logs on host

- evaluation warning: cloud-hypervisor supports systemd-notify via vsock, but `microvm.vsock.cid` must be set to enable this.
