#!/bin/bash
# Installskript für ai-hedge-fund (https://github.com/virattt/ai-hedge-fund)
# Entwickelt für Debian/Ubuntu (Proxmox LXC/VM)
# Inklusive Start der Streamlit Web-App (UI) in Tmux.

# --- Konfiguration ---
INSTALL_DIR="$HOME/ai-hedge-fund"
REPO_URL="https://github.com/virattt/ai-hedge-fund.git"
USER_NAME=$(whoami)
TMUX_SESSION="ai_hedge_fund_ui" # Tmux Session Name

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
if ! command -v wget &> /dev/null; then
    sudo apt update && sudo apt install -y wget -y
fi
if ! command -v curl &> /dev/null; then
    sudo apt update && sudo apt install -y curl -y
fi
if ! command -v tmux &> /dev/null; then
    sudo apt update && sudo apt install -y tmux -y
fi

sudo apt update || log_error "Aktualisierung der Paketlisten fehlgeschlagen."
# Stellen Sie sicher, dass 'tmux' installiert ist
sudo apt install -y git python3 python3-pip tmux || log_error "Installation der System-Abhängigkeiten fehlgeschlagen."

# 2. Poetry Installation
log_info "Installiere Python-Abhängigkeitsmanager Poetry..."
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3 - || log_error "Installation von Poetry fehlgeschlagen."
    
    # Fügen Sie Poetry zum PATH der aktuellen Shell und zur .bashrc/oder .zshrc hinzu
    export PATH="$HOME/.local/bin:$PATH"
    
    # Permanentes Hinzufügen des PATH für den aktuellen Benutzer
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
PROJECT_ROOT=$(pwd) # Speichere den Wurzelpfad

# 4. Python-Abhängigkeiten installieren (Streamlit wird hier installiert)
log_info "Installiere Python-Abhängigkeiten mit Poetry. Das kann einige Minuten dauern..."
export PATH="$HOME/.local/bin:$PATH" # PATH sicherstellen

poetry install || log_error "Installation der Python-Abhängigkeiten mit Poetry fehlgeschlagen."

# 5. Konfiguration (API-Schlüssel) vorbereiten
log_info "Bereite die .env Konfigurationsdatei vor..."
ENV_FILE="$PROJECT_ROOT/.env"
if [ ! -f "$ENV_FILE" ]; then
    cp .env.example "$ENV_FILE"
    log_info "Eine .env-Datei wurde basierend auf .env.example erstellt."
    log_info "!!! WICHTIG: Sie müssen Ihre API-Schlüssel manuell eintragen (Schritt 6) !!!"
else
    log_info "Die .env-Datei existiert bereits."
fi

# 6. Dienste in TMUX starten (Web UI und optional CLI)
log_info "Starte die Streamlit Web-UI in der Tmux-Sitzung '$TMUX_SESSION'..."

# Prüfen, ob die Sitzung bereits existiert
tmux has-session -t "$TMUX_SESSION" 2>/dev/null

if [ $? != 0 ]; then
    echo "Starte neue Tmux-Sitzung: $TMUX_SESSION"
    tmux new-session -d -s "$TMUX_SESSION"
    
    # Fenster 0: Streamlit Web-App (UI - Port 8501)
    tmux send-keys -t "$TMUX_SESSION:0" "cd $PROJECT_ROOT" C-m
    # Startet Streamlit, das standardmäßig auf Port 8501 läuft
    tmux send-keys -t "$TMUX_SESSION:0" "poetry run streamlit run src/web_app.py --server.port 8501" C-m
    tmux rename-window -t "$TMUX_SESSION:0" "Streamlit-UI (8501)"

    # Neues Fenster 1: CLI (für Tests oder andere Befehle)
    tmux new-window -t "$TMUX_SESSION:1" -n "CLI-Shell"
    tmux send-keys -t "$TMUX_SESSION:1" "cd $PROJECT_ROOT" C-m
    tmux send-keys -t "$TMUX_SESSION:1" "poetry shell" C-m
    
    log_success "Streamlit UI und Tmux-Sitzung gestartet!"
    echo "========================================================"
    echo "✅ INSTALLATION UND START ERFOLGREICH!"
    echo "Frontend-UI (Streamlit) ist verfügbar unter: http://[Ihre VM-IP-Adresse]:8501"
    echo "--------------------------------------------------------"
    echo "WICHTIG: API-Key Eintragen!"
    echo "1. Drücken Sie Strg+B und dann [0], um zur Streamlit-UI-Konsole zu wechseln."
    echo "2. Drücken Sie Strg+B und dann [1], um in die Poetry-Shell zu wechseln."
    echo "3. Beenden Sie die Tmux-Sitzung (Strg+B, dann D) und bearbeiten Sie dann die Datei:"
    echo "   nano $INSTALL_DIR/.env"
    echo "   Tragen Sie Ihren OPENAI_API_KEY ein und speichern Sie."
    echo "4. Verbinden Sie sich erneut: tmux attach -t $TMUX_SESSION"
    echo "--------------------------------------------------------"
    
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits. Verbinde neu."
fi

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
