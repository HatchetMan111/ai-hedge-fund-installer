#!/bin/bash
# Installskript für ai-hedge-fund (https://github.com/virattt/ai-hedge-fund)
# Entwickelt für Debian/Ubuntu (Proxmox LXC/VM)
# Kann direkt von GitHub ausgeführt werden:
# wget -qO - https://raw.githubusercontent.com/<YOUR_GITHUB_USER>/<YOUR_REPO_NAME>/main/install_ai_hedge_fund.sh | bash

# --- Konfiguration ---
INSTALL_DIR="$HOME/ai-hedge-fund"
REPO_URL="https://github.com/virattt/ai-hedge-fund.git"
USER_NAME=$(whoami)

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

# --- Hauptinstallation ---

log_info "Starte die Installation des ai-hedge-fund..."
log_info "Aktualisiere System und installiere grundlegende Pakete..."

# 1. Systemaktualisierung und Abhängigkeiten
# Installiere `wget` falls noch nicht vorhanden, da es für curl install benötigt wird
if ! command -v wget &> /dev/null; then
    sudo apt update && sudo apt install -y wget
fi
if ! command -v curl &> /dev/null; then
    sudo apt update && sudo apt install -y curl
fi

sudo apt update || log_error "Aktualisierung der Paketlisten fehlgeschlagen."
sudo apt install -y git python3 python3-pip || log_error "Installation der System-Abhängigkeiten fehlgeschlagen."

# 2. Poetry Installation
log_info "Installiere Python-Abhängigkeitsmanager Poetry..."
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3 - || log_error "Installation von Poetry fehlgeschlagen."
    
    # Fügen Sie Poetry zum PATH der aktuellen Shell und zur .bashrc/oder .zshrc hinzu
    export PATH="$HOME/.local/bin:$PATH"
    
    # Permanentes Hinzufügen des PATH für den aktuellen Benutzer
    # Überprüfen, ob es bereits in der .bashrc enthalten ist, um Duplikate zu vermeiden
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    log_success "Poetry wurde erfolgreich installiert und zum PATH hinzugefügt."
else
    log_info "Poetry ist bereits installiert."
fi

# 3. Repository klonen
log_info "Klone das ai-hedge-fund Repository nach $INSTALL_DIR..."
if [ -d "$INSTALL_DIR" ]; then
    log_info "Verzeichnis existiert bereits. Lösche das alte Verzeichnis..."
    rm -rf "$INSTALL_DIR" || log_error "Löschen des alten Verzeichnisses fehlgeschlagen."
fi

git clone "$REPO_URL" "$INSTALL_DIR" || log_error "Klonen des Repositorys fehlgeschlagen."
cd "$INSTALL_DIR" || log_error "Wechseln in das Installationsverzeichnis fehlgeschlagen."

# 4. Python-Abhängigkeiten installieren
log_info "Installiere Python-Abhängigkeiten mit Poetry. Das kann einige Minuten dauern..."
# Stellen Sie sicher, dass Poetry im aktuellen Shell-Kontext verfügbar ist, falls es gerade erst installiert wurde
export PATH="$HOME/.local/bin:$PATH"

poetry install || log_error "Installation der Python-Abhängigkeiten mit Poetry fehlgeschlagen."

# 5. Konfiguration (API-Schlüssel) vorbereiten
log_info "Bereite die .env Konfigurationsdatei vor..."
if [ ! -f .env ]; then
    cp .env.example .env
    log_info "Eine .env-Datei wurde basierend auf .env.example erstellt."
    log_info "BITTE BEACHTEN SIE: Sie müssen nun die Datei $INSTALL_DIR/.env bearbeiten und Ihre OPENAI_API_KEY (und ggf. weitere Schlüssel) eintragen."
else
    log_info "Die .env-Datei existiert bereits."
fi

# 6. Abschluss und Anweisungen
log_success "Die Installation des ai-hedge-fund ist abgeschlossen!"

echo "--- Nächste Schritte ---"
echo "1. Wechseln Sie in das Installationsverzeichnis:"
echo "   cd $INSTALL_DIR"
echo "2. Bearbeiten Sie die Konfigurationsdatei und fügen Sie Ihre API-Schlüssel hinzu:"
echo "   nano .env"
echo "3. Führen Sie die Anwendung aus. Beispiele:"
echo "   # Führen Sie die CLI aus:"
echo "   poetry run python src/main.py --ticker AAPL,MSFT,NVDA"
echo "   # Starten Sie die Webanwendung (falls gewünscht, siehe GitHub für Details):"
echo "   poetry run streamlit run src/web_app.py"

echo "------------------------"
log_info "Um Poetry nach dem nächsten Login zu nutzen, starten Sie die Shell neu oder führen Sie 'source ~/.bashrc' aus."
