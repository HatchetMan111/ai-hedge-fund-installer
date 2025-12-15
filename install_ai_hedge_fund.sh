#!/bin/bash
#
# FILE: install_ai_hedge_fund_FINAL_STREAMLIT.sh
# Installation und Start des virattt/ai-hedge-fund Projekts (Streamlit-Version).
# Behebt fehlende Poetry-Abhängigkeiten und korrigiert Tmux-Startbefehle.
#
set -e

# --- KONFIGURATION ---
INSTALL_DIR="$HOME/ai-hedge-fund"
REPO_URL="https://github.com/virattt/ai-hedge-fund.git"
TMUX_SESSION="ai_hedge_fund_ui"
STREAMLIT_PORT="8501"

# --- FUNKTIONEN ---

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

# Funktion zur Ermittlung der IP-Adresse
get_ip_address() {
    # Versucht, die primäre IP-Adresse der Standard-Route zu ermitteln
    IP=$(ip route get 1 | awk '{print $NF; exit}')
    if [[ -z "$IP" ]]; then
        # Fallback für andere Systeme
        IP=$(hostname -I | awk '{print $1}')
    fi
    echo "$IP"
}

# --- HAUPTINSTALLATION ---

log_info "Starte die Installation des ai-hedge-fund (Streamlit-Version)..."

# 1. Systemaktualisierung und Abhängigkeiten
log_info "1/7: Installation der System-Abhängigkeiten (git, python, tmux)..."
sudo apt update || log_error "Aktualisierung der Paketlisten fehlgeschlagen."
sudo apt install -y git python3 python3-pip curl tmux || log_error "Installation der System-Abhängigkeiten fehlgeschlagen."

# 2. Poetry Installation
log_info "2/7: Installation von Poetry..."
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3 - || log_error "Installation von Poetry fehlgeschlagen."
    export PATH="$HOME/.local/bin:$PATH"
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    log_success "Poetry wurde erfolgreich installiert."
else
    log_info "Poetry ist bereits installiert."
fi
export PATH="$HOME/.local/bin:$PATH" # PATH im aktuellen Kontext sicherstellen

# 3. Repository klonen
log_info "3/7: Klone das ai-hedge-fund Repository..."
if [ -d "$INSTALL_DIR" ]; then
    log_info "Lösche altes Verzeichnis..."
    rm -rf "$INSTALL_DIR" || log_error "Löschen des alten Verzeichnisses fehlgeschlagen."
fi
git clone "$REPO_URL" "$INSTALL_DIR" || log_error "Klonen des Repositorys fehlgeschlagen."
cd "$INSTALL_DIR" || log_error "Wechseln in das Installationsverzeichnis fehlgeschlagen."
PROJECT_ROOT=$(pwd)

# 4. KRITISCHER FIX: Fehlende Abhängigkeiten hinzufügen
log_info "4/7: Behebe fehlende Streamlit-Abhängigkeiten in pyproject.toml..."
# Diese Pakete fehlen laut Ihren Fehlerprotokollen
poetry add streamlit || log_error "Hinzufügen von streamlit fehlgeschlagen."
poetry add pandas numpy plotly || log_error "Hinzufügen von Datenanalyse-Paketen fehlgeschlagen."
poetry add yfinance || log_error "Hinzufügen von yfinance fehlgeschlagen."
log_success "Streamlit und notwendige Pakete wurden zur Konfiguration hinzugefügt."

# 5. Python-Abhängigkeiten installieren
log_info "5/7: Installiere alle Python-Abhängigkeiten mit Poetry..."
poetry install || log_error "Installation der Python-Abhängigkeiten mit Poetry fehlgeschlagen."

# 6. Konfiguration vorbereiten
log_info "6/7: Bereite die .env Konfigurationsdatei vor..."
if [ ! -f .env ]; then
    cp .env.example .env
    log_info "Eine .env-Datei wurde erstellt. BITTE DEN OPENAI_API_KEY EINFÜGEN."
fi

# 7. Starten der Dienste in TMUX
log_info "7/7: Starte die Streamlit Web-UI in der Tmux-Sitzung '$TMUX_SESSION'..."

# Tmux-Sitzung beenden, falls sie noch von einem vorherigen (fehlerhaften) Lauf existiert
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

# Starte neue Tmux-Sitzung
tmux new-session -d -s "$TMUX_SESSION"

# Fenster 0: Streamlit Web-App (UI - Port 8501) - KORRIGIERTER BEFEHL
tmux send-keys -t "$TMUX_SESSION:0" "cd $PROJECT_ROOT" C-m
tmux send-keys -t "$TMUX_SESSION:0" "poetry run python -m streamlit run src/web_app.py --server.port $STREAMLIT_PORT" C-m
tmux rename-window -t "$TMUX_SESSION:0" "Streamlit-UI ($STREAMLIT_PORT)"

# Fenster 1: CLI (Poetry Shell - KORRIGIERTER BEFEHL)
tmux new-window -t "$TMUX_SESSION:1" -n "CLI-Shell"
tmux send-keys -t "$TMUX_SESSION:1" "cd $PROJECT_ROOT" C-m
tmux send-keys -t "$TMUX_SESSION:1" "poetry run bash" C-m # Korrigiert für neuere Poetry-Versionen

log_success "Installation und Start in Tmux abgeschlossen!"

# --- ABSCHLUSSAUSGABE ---
VM_IP=$(get_ip_address)
log_success "Die AI Hedge Fund UI wurde erfolgreich gestartet!"

echo "========================================================"
echo "      🚀 BEREIT ZUM START 🚀"
echo "--------------------------------------------------------"
echo "🌐 Frontend-UI (Streamlit) ist verfügbar unter:"
echo "   http://$VM_IP:$STREAMLIT_PORT"
echo "--------------------------------------------------------"
echo "1. API-Key eintragen: Bearbeiten Sie die Datei $PROJECT_ROOT/.env"
echo "2. Tmux verbinden: tmux attach -t $TMUX_SESSION"
echo "3. Im Tmux-Fenster 0 (Streamlit) neu starten (Strg+C, dann Enter)."
echo "========================================================"

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
