#!/bin/bash
#
# FILE: install_ai_hedge_fund.sh
# DESCRIPTION: Vollständiges Installations- und Startskript für das AI-Hedge-Fund Projekt.
# Führt alle System- und Projekt-Abhängigkeiten sowie den Start in tmux durch.
# AUTHOR: Gemini AI Assistent & HatchetFondAI User
#
# VERWENDUNG: 
#   Auf einer frischen Ubuntu VM:
#   wget -qO - https://raw.githubusercontent.com/[Ihr User]/[Ihr Repo]/main/install_ai_hedge_fund.sh | bash
#
set -e # Beendet das Skript sofort bei einem Fehler

PROJECT_DIR="ai-hedge-fund"
TMUX_SESSION="ai_hedge_fund_session"
REPO_URL="https://github.com/HatchetMan111/ai-hedge-fund.git" # PASST DIESEN PFAD AN IHR REPO AN!

echo "========================================================"
echo "      AI Hedge Fund - Vollständiges Setup & Start"
echo "========================================================"

# --- 1. System-Vorbereitung (apt, Build-Tools, Node.js, Git) ---
echo "--- 1/6: Installation der System-Abhängigkeiten & Updates ---"
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git

# Node.js LTS 20 installieren (für das Frontend)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js (Version: $(node -v)) bereits installiert."
fi

# --- 2. Poetry-Installation und PATH-Konfiguration ---
echo "--- 2/6: Installation von Poetry (Python-Paketmanager) ---"
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    # Poetry zum PATH der aktuellen Shell hinzufügen
    export PATH="$HOME/.local/bin:$PATH"
    echo "Poetry erfolgreich installiert und zum PATH hinzugefügt."
else
    echo "Poetry bereits installiert."
fi

# --- 3. Klonen des Repositories ---
echo "--- 3/6: Klonen des Projekt-Repositories ---"
if [ -d "$PROJECT_DIR" ]; then
    echo "Projektverzeichnis '$PROJECT_DIR' existiert bereits. Überspringe Klonen."
    cd "$PROJECT_DIR"
else
    git clone "$REPO_URL"
    cd "$PROJECT_DIR"
fi
PROJECT_ROOT=$(pwd)

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

# Korrektur des fehlerhaften Imports (layout -> Layout.tsx)
if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an: './components/layout' -> './components/Layout.tsx'"
    # Der sed-Befehl ersetzt die fehlerhafte Zeile
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
    tmux send-keys -t "$TMUX_SESSION:0" "export PATH=$HOME/.local/bin:$PATH && poetry run uvicorn app.backend.main:app --host 0.0.0.0 --reload" C-m
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
    echo "Verwenden Sie 'tmux attach -t $TMUX_SESSION' zum Wiederaufnehmen."
    
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits."
fi

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
