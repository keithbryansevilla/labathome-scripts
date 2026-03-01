#!/bin/bash
set -e

VM_ID=100
VM_NAME="ubuntu-vm-template"
CI_USER="ubuntu"
SSH_KEYFILE="$HOME/.ssh/id_rsa.pub"
IMG_URL="http://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_PATH="/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img"

if [ ! -f "$SSH_KEYFILE" ]; then
  echo "ERROR: SSH public key not found at $SSH_KEYFILE"
  exit 1
fi

if [ ! -f "$IMG_PATH" ]; then
  echo "Downloading Ubuntu Noble cloud image..."
  wget -O "$IMG_PATH" "$IMG_URL"
else
  echo "Cloud image already present, skipping download."
fi

echo "Creating VM $VM_ID ($VM_NAME)..."
qm create "$VM_ID" \
  --name "$VM_NAME" \
  --memory 2048 \
  --cores 2 \
  --cpu host \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26 \
  --agent enabled=1

echo "Importing disk..."
qm importdisk "$VM_ID" "$IMG_PATH" local-lvm

echo "Configuring VM..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-${VM_ID}-disk-0
qm set "$VM_ID" --ide2 local-lvm:cloudinit
qm set "$VM_ID" --boot c --bootdisk scsi0
qm set "$VM_ID" --serial0 socket --vga serial0

qm resize "$VM_ID" scsi0 20G

echo "Applying Cloud-Init settings..."
read -s -p "CI Password: " CI_PASS
qm set "$VM_ID" --ciuser ubuntu --cipassword "$CI_PASS"
qm set "$VM_ID" --sshkeys ~/.ssh/id_rsa.pub
qm set "$VM_ID" --ipconfig0 ip=dhcp

echo "Converting to template..."
qm template "$VM_ID"

