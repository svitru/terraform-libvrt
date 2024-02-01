terraform {
 required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  count		 = 4
  name           = "commoninit-${count.index}.iso"
  user_data = <<EOF
#cloud-config
hostname: node-${count.index}
disable_root: 0
users:
  - name: user
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh-authorized-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDLLtaUqKmi6yxE4L1NrQB7x4cCrO7pCnlvUNLXImkLN
  - name: root
    shell: /bin/bash
    lock_passwd: true
    ssh-authorized-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDLLtaUqKmi6yxE4L1NrQB7x4cCrO7pCnlvUNLXImkLN
growpart:
  mode: auto
  devices: ['/']
EOF
  
  network_config = <<EOF
version: 2
ethernets:
  ens3:
    dhcp4: true

EOF

}

resource "libvirt_volume" "os_image" {
  name   = "os_image"
  source = "ubuntu-22.04-server-cloudimg-amd64.img" # downloaded from https://cloud-images.ubuntu.com/releases/jammy/release/
}

resource "libvirt_volume" "volume" {
  name           = "volume-${count.index}"
  base_volume_id = libvirt_volume.os_image.id
  count          = 4
  size		 = 10737418240
}

resource "libvirt_domain" "domain" {
  name = "node-${count.index}"

  cloudinit = element(libvirt_cloudinit_disk.commoninit.*.id, count.index)

  vcpu = 4
  memory = 4096

  disk {
    volume_id = element(libvirt_volume.volume.*.id, count.index)
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  count = 4
}

output "ips" {
  value = libvirt_domain.domain.*.network_interface.0.addresses
}
