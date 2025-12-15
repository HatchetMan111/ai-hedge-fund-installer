#!/bin/bash
#
# FILE: install_ai_hedge_fund.sh
# KORRIGIERTE & VERBESSERTE VERSION
# Behandelt PATH-Probleme, Klon-Fehler und den Layout.tsx-Fix.
#
set -e # Beendet das Skript sofort bei einem Fehler

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
TMUX_SESSION="ai_hedge_fund_session"
# Wichtig: Die HTTPS-URL für das Klonen beibehalten, da sie einfacher zu verwenden ist.
REPO_URL="https://github.com/HatchetMan111/ai-hedge-fund.git" 
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      AI Hedge Fund - Vollständiges Setup & Start"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
exec > >(tee -a "$LOG_FILE") 2>&1 # Leitet stdout und stderr an die Konsole und die Log-Datei um

# --- GLOBALE PATH-Anpassung für die aktuelle Shell ---
# Stellt sicher, dass das lokale Bin-Verzeichnis immer im Pfad ist, um Poetry sofort zu finden.
export PATH="$HOME/.local/bin:$PATH"

# --- 1. System-Vorbereitung (apt, Build-Tools, Node.js, Git) ---
echo "--- 1/6: Installation der System-Abhängigkeiten ---"
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git

# Node.js LTS 20 installieren
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js (Version: $(node -v)) bereits installiert."
fi

# --- 2. Poetry-Installation ---
echo "--- 2/6: Installation von Poetry (Python-Paketmanager) ---"
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    echo "Poetry erfolgreich installiert."
else
    echo "Poetry bereits installiert."
fi

# --- 3. Klonen des Repositories ---
echo "--- 3/6: Klonen des Projekt-Repositories ---"

# Bereinigen alter Reste, falls vorhanden
if [ -d "$PROJECT_DIR" ]; then
    echo "Projektverzeichnis '$PROJECT_DIR' existiert. Lösche es, um einen sauberen Klon zu gewährleisten."
    rm -rf "$PROJECT_DIR"
fi

echo "Starte Klonen von $REPO_URL..."
if ! git clone "$REPO_URL"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER BEIM KLONEN !!!"
    echo "Der Klon-Vorgang von $REPO_URL ist fehlgeschlagen."
    echo "Mögliche Ursache: Das Repository ist nicht öffentlich oder es liegt ein Authentifizierungsfehler vor."
    echo "Bitte stellen Sie sicher, dass das Repository wirklich öffentlich ist und führen Sie das Skript erneut aus."
    echo "--------------------------------------------------------"
    exit 1
fi

cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)
echo "Klonen erfolgreich. Aktuelles Verzeichnis: $PROJECT_ROOT"

# --- 4. Projekt-Abhängigkeiten installieren ---
echo "--- 4/6: Installation der Backend (Poetry) & Frontend (npm) Abhängigkeiten ---"

echo "-> Installation Backend (Poetry)..."
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT" # Zurück zum Wurzelverzeichnis

# --- 5. Fix für Case-Sensitivity (Layout-Import) ---
echo "--- 5/6: Anwenden des notwendigen Fixes für den Layout.tsx-Import (Linux) ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"

if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an: './components/layout' -> './components/Layout.tsx'"
    # sed-Befehl ersetzt die fehlerhafte Zeile
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
else
    echo "Fix ist bereits angewandt oder Importstruktur wurde geändert."
fi

# --- 6. Start der Dienste in TMUX ---
echo "--- 6/6: Starten der Dienste in der Tmux-Sitzung '$TMUX_SESSION' ---"

# Prüfen, ob die Sitzung bereits existiert
tmux has-session -t "$TMUX_SESSION" 2>/dev/null

if [ $? != 0 ]; then
    echo "Starte neue Tmux-Sitzung: $TMUX_SESSION"
    tmux new-session -d -s "$TMUX_SESSION"
    
    # Fenster 0: Backend starten (API - Port 8000)
    tmux send-keys -t "$TMUX_SESSION:0" "cd $PROJECT_ROOT" C-m
    # Start mit Poetry (PATH ist hier kritisch, wird aber von der Bash-Session am Anfang geerbt)
    tmux send-keys -t "$TMUX_SESSION:0" "poetry run uvicorn app.backend.main:app --host 0.0.0.0 --reload" C-m
    tmux rename-window -t "$TMUX_SESSION:0" "Backend-API (8000)"

    # Neues Fenster 1: Frontend starten (UI - Port 5173)
    tmux new-window -t "$TMUX_SESSION:1" -n "Frontend-UI (5173)"
    tmux send-keys -t "$TMUX_SESSION:1" "cd $PROJECT_ROOT/app/frontend" C-m
    tmux send-keys -t "$TMUX_SESSION:1" "npm run dev -- --host 0.0.0.0" C-m
    
    echo "========================================================"
    echo "✅ INSTALLATION UND START ERFOLGREICH!"
    echo "Frontend-UI ist verfügbar unter: http://[Ihre VM-IP-Adresse]:5173"
    echo "Backend-API (Docs) ist verfügbar unter: http://[Ihre VM-IP-Adresse]:8000/docs"
    echo "--------------------------------------------------------"
    echo "Drücken Sie Strg+B und dann [N] oder [P], um zwischen Frontend und Backend zu wechseln."
    
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits. Verbinde neu."
fi

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
