#!/bin/bash
#
# DATEI: install_ai_hedge_fund.sh
# ZWECK: Vollständige Installation, Konfiguration und Start der AI-Hedge-Fund-Anwendung.
#
set -e # Beendet das Skript sofort bei einem Fehler

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
TMUX_SESSION="ai_hedge_fund_session"
# KRITISCH: NUTZT SSH-KLONEN. SSH-SCHLÜSSEL MUSS ZU GITHUB HINZUGEFÜGT WERDEN!
REPO_URL="git@github.com:HatchetMan111/ai-hedge-fund.git" 
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      AI Hedge Fund - Vollständiges Setup & Start"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
exec > >(tee -a "$LOG_FILE") 2>&1

# --- GLOBALE PATH-Anpassung (für Poetry) ---
# Stellt sicher, dass das Poetry-Binärverzeichnis immer im PATH ist.
export PATH="$HOME/.local/bin:$PATH"

# --- 1/6: System-Vorbereitung (apt, Build-Tools, Node.js) ---
echo "--- 1/6: Installation der System-Abhängigkeiten ---"
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git nano

# Node.js LTS 20 installieren (für das Frontend)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js (Version: $(node -v)) bereits installiert."
fi

# --- 2/6: Poetry-Installation ---
echo "--- 2/6: Installation von Poetry (Python-Paketmanager) ---"
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    echo "Poetry erfolgreich installiert."
else
    echo "Poetry bereits installiert."
fi

# --- 3/6: Klonen des Repositories via SSH ---
echo "--- 3/6: Klonen des Projekt-Repositories via SSH ---"

# Bereinigen alter Reste
if [ -d "$PROJECT_DIR" ]; then
    echo "Projektverzeichnis '$PROJECT_DIR' existiert. Lösche es, um einen sauberen Klon zu gewährleisten."
    rm -rf "$PROJECT_DIR"
fi

# Prüfung, ob SSH-Schlüssel existiert (kritisch für SSH-Klonen)
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: SSH-Schlüssel nicht gefunden !!!"
    echo "Bitte generieren Sie den Schlüssel und fügen Sie ihn zu GitHub hinzu."
    echo "Generieren: ssh-keygen -t rsa -b 4096 -C 'vm-key'"
    echo "--------------------------------------------------------"
    exit 1
fi

echo "Starte Klonen von $REPO_URL..."
if ! git clone "$REPO_URL"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER BEIM KLONEN !!!"
    echo "Mögliche Ursache: SSH-Schlüssel fehlt oder ist GitHub unbekannt."
    echo "--------------------------------------------------------"
    exit 1
fi

cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)
echo "Klonen erfolgreich. Aktuelles Verzeichnis: $PROJECT_ROOT"

# --- 4/6: Projekt-Abhängigkeiten installieren ---
echo "--- 4/6: Installation der Backend (Poetry) & Frontend (npm) Abhängigkeiten ---"

echo "-> Installation Backend (Poetry)..."
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT" # Zurück zum Wurzelverzeichnis

# --- 5/6: Fix für Case-Sensitivity (Layout-Import) ---
echo "--- 5/6: Anwenden des notwendigen Fixes für den Layout.tsx-Import (Linux) ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"

if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an: './components/layout' -> './components/Layout.tsx'"
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
else
    echo "Fix ist bereits angewandt oder Importstruktur wurde geändert."
fi

# --- 6/6: Start der Dienste in TMUX ---
echo "--- 6/6: Starten der Dienste in der Tmux-Sitzung '$TMUX_SESSION' ---"

# Tmux-Sitzung stoppen, falls sie von einem vorherigen Lauf existiert
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

echo "Starte neue Tmux-Sitzung: $TMUX_SESSION"
tmux new-session -d -s "$TMUX_SESSION"

# Fenster 0: Backend starten (API - Port 8000)
tmux send-keys -t "$TMUX_SESSION:0" "cd $PROJECT_ROOT" C-m
tmux send-keys -t "$TMUX_SESSION:0" "poetry run uvicorn app.backend.main:app --host 0.0.0.0 --reload" C-m
tmux rename-window -t "$TMUX_SESSION:0" "Backend-API (8000)"

# Neues Fenster 1: Frontend starten (UI - Port 5173)
tmux new-window -t "$TMUX_SESSION:1" -n "Frontend-UI (5173)"
tmux send-keys -t "$TMUX_SESSION:1" "cd $PROJECT_ROOT/app/frontend" C-m
tmux send-keys -t "$TMUX_SESSION:1" "npm run dev -- --host 0.0.0.0" C-m

echo "========================================================"
echo "      ✅ INSTALLATION ERFOLGREICH ABGESCHLOSSEN! ✅"
echo "========================================================"
echo "Der AI-Hedge-Fund läuft jetzt, benötigt aber einen API-Schlüssel."
echo "--------------------------------------------------------"
echo "ANLEITUNG ZUM ABSCHLUSS:"
echo "--------------------------------------------------------"
echo "1. API-Key eintragen:"
echo "   Öffnen Sie die Konfigurationsdatei mit nano:"
echo "   nano $PROJECT_ROOT/.env"
echo "   Fügen Sie die Zeile OPENAI_API_KEY=\"IHR_SCHLÜSSEL\" ein."
echo "   Speichern: Strg+O, Enter. Schließen: Strg+X."
echo ""
echo "2. Tmux verbinden und neu starten:"
echo "   Verbinden Sie sich mit der laufenden Sitzung:"
echo "   tmux attach -t $TMUX_SESSION"
echo ""
echo "   Im Tmux-Fenster (Frontend-UI 5173):"
echo "   Stoppen: Strg+C"
echo "   Neu starten: Enter"
echo "--------------------------------------------------------"
echo "🌐 Frontend-UI (Vite) ist erreichbar unter: http://[Ihre VM-IP-Adresse]:5173"
echo "💻 Backend-API (Docs) ist erreichbar unter: http://[Ihre VM-IP-Adresse]:8000/docs"
echo "--------------------------------------------------------"

# Sitzung wieder aufnehmen, damit der Benutzer sofort die Logs sieht
tmux attach -t "$TMUX_SESSION"
