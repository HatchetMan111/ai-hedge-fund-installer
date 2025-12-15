#!/bin/bash
# Skript zur automatischen Bereitstellung einer Proxmox VM mit ai-hedge-fund
# Auszuführen auf dem Proxmox Host-System.

# --- Konfiguration ---
VM_ID="900"                                         # Eindeutige VM-ID
VM_NAME="ai-hedge-fund-vm"                          # Name der VM
DISK_SIZE="32G"                                     # Größe der Root-Disk
MEMORY="4096"                                       # RAM in MB (4 GB)
CPU_CORES="2"                                       # Anzahl der CPU-Kerne
STORAGE_POOL="local-lvm"                            # Speicher-Pool für die VM-Disk (Anpassen!)
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
LOCAL_IMAGE_PATH="/var/lib/vz/template/qemu/debian-12-generic-amd64.qcow2"
VM_USER="aiuser"                                    # Standard-Benutzername in der Cloud-VM
SSH_PUBLIC_KEY_FILE="$HOME/.ssh/id_rsa.pub"         # Pfad zum öffentlichen SSH-Schlüssel
SSH_PRIVATE_KEY_FILE="$HOME/.ssh/id_rsa"            # Pfad zum privaten SSH-Schlüssel
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/HatchetMan111/ai-hedge-fund-installer/main/install_ai_hedge_fund.sh" # Ihr Installer

# --- Funktionen ---

log_info() {
    echo -e "\n\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\n\033[1;32m[ERFOLG]\033[0m $1"
}

log_error() {
    echo -e "\n\033[1;31m[FEHLER]\033[0m $1" >&2
    exit 1
}

# 1. Prüfe Voraussetzungen
if [[ ! -f "$SSH_PUBLIC_KEY_FILE" ]] || [[ ! -f "$SSH_PRIVATE_KEY_FILE" ]]; then
    log_error "SSH-Schlüsselpaar nicht gefunden! Bitte erstellen Sie es zuerst:\nssh-keygen -t rsa -b 4096\nStellen Sie sicher, dass der Pfad korrekt ist: $HOME/.ssh/id_rsa"
fi

# 2. Image herunterladen
if [ ! -f "$LOCAL_IMAGE_PATH" ]; then
    log_info "Lade Debian Cloud Image herunter..."
    mkdir -p $(dirname "$LOCAL_IMAGE_PATH")
    wget -qO "$LOCAL_IMAGE_PATH" "$IMAGE_URL" || log_error "Download des Cloud Images fehlgeschlagen."
fi

# 3. VM erstellen und konfigurieren
log_info "Erstelle VM $VM_ID ($VM_NAME) auf Proxmox..."

# VM erstellen
qm create $VM_ID --name $VM_NAME --memory $MEMORY --cores $CPU_CORES --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --vga qxl --agent 1
if [ $? -ne 0 ]; then log_error "Fehler beim Erstellen der VM (qm create)."; fi

# Festplatte importieren und vergrößern
qm importdisk $VM_ID "$LOCAL_IMAGE_PATH" "$STORAGE_POOL"
qm set $VM_ID --scsi0 "$STORAGE_POOL":vm-$VM_ID-disk-0
qm set $VM_ID --boot c --bootdisk scsi0
qm set $VM_ID --scsihw virtio-scsi-pci
qm resize $VM_ID scsi0 $DISK_SIZE
qm set $VM_ID --serial0 socket

# Cloud-Init Konfiguration
log_info "Konfiguriere Cloud-Init für SSH und Benutzer $VM_USER..."
qm set $VM_ID --ciuser $VM_USER
qm set $VM_ID --cipassword 'ProxmoxStandardPasswort' # Kann später entfernt oder geändert werden
qm set $VM_ID --ipconfig0 ip=dhcp
qm set $VM_ID --sshkeys $(cat "$SSH_PUBLIC_KEY_FILE")
qm set $VM_ID --ci-ide2 cdrom=none # CD-ROM als Cloud-Init-Device entfernen, da es Probleme machen kann
qm set $VM_ID --ide2 "$STORAGE_POOL":cloudinit

log_success "VM-Konfiguration abgeschlossen."

# 4. VM starten und auf Verfügbarkeit warten
log_info "Starte VM und warte auf die IP-Adresse..."
qm start $VM_ID

# Warte maximal 120 Sekunden auf die IP-Adresse über den QEMU-Agenten
VM_IP=""
ATTEMPTS=0
MAX_ATTEMPTS=24
while [ -z "$VM_IP" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    sleep 5
    VM_IP=$(qm agent $VM_ID network-get-interfaces 2>/dev/null | grep -A 1 'ip-address' | tail -1 | awk -F '"' '{print $4}' | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    ATTEMPTS=$((ATTEMPTS + 1))
    echo "Versuch $ATTEMPTS/$MAX_ATTEMPTS: Warte auf IP-Adresse..."
done

if [ -z "$VM_IP" ]; then
    log_error "Konnte die IP-Adresse der VM $VM_ID nicht ermitteln. Breche ab."
fi

log_success "VM läuft. IP-Adresse: $VM_IP"

# 5. ai-hedge-fund Installation in der VM
log_info "Installiere ai-hedge-fund in der VM über SSH ($VM_USER@$VM_IP)..."

# SSH-Verbindung aufbauen und Installationsskript ausführen
# Wir müssen den SSH-Key direkt angeben, da wir als root auf dem Host laufen, aber als $VM_USER in der VM
INSTALL_COMMAND="wget -qO - $INSTALL_SCRIPT_URL | bash"
SSH_OPTS="-i $SSH_PRIVATE_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_TARGET="$VM_USER@$VM_IP"

# Warte kurz, um sicherzustellen, dass SSH bereit ist
sleep 10

ssh $SSH_OPTS "$SSH_TARGET" "$INSTALL_COMMAND"
if [ $? -ne 0 ]; then log_error "Installation des ai-hedge-fund in der VM fehlgeschlagen."; fi

# 6. Abschluss
log_success "Die VM $VM_NAME ($VM_ID) mit ai-hedge-fund ist bereit!"
echo "--------------------------------------------------------"
echo "Zugangsdaten:"
echo "Benutzer: $VM_USER"
echo "IP-Adresse: $VM_IP"
echo "SSH-Befehl: ssh -i $SSH_PRIVATE_KEY_FILE $VM_USER@$VM_IP"
echo ""
echo "Nächster Schritt: Verbinden Sie sich und bearbeiten Sie die API-Schlüssel in ~/ai-hedge-fund/.env"
echo "--------------------------------------------------------"
