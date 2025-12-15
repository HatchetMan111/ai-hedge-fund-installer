#!/bin/bash
#
# FILE: install_and_start.sh
# DESCRIPTION: Vollständige Installation und Start der AI-Hedge-Fund-Anwendung (Backend & Frontend).
# AUTHOR: Gemini AI Assistent & HatchetFondAI User
#
# VERWENDUNG: 
#   1. Stelle sicher, dass Poetry auf dem System installiert ist.
#   2. Führe das Skript aus: ./install_and_start.sh
#
set -e # Beendet das Skript sofort bei einem Fehler

PROJECT_ROOT=$(pwd)
TMUX_SESSION="ai_hedge_fund"

echo "========================================================"
echo "           AI Hedge Fund - Setup & Start Script"
echo "========================================================"

# --- 1. System-Vorbereitung (apt, Build-Tools, Tmux, Node.js) ---
echo "--- 1/5: Installation der System-Abhängigkeiten ---"
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git

# Node.js LTS 20 installieren (falls nicht vorhanden)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20 LTS for frontend..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js already installed."
fi

# --- 2. Backend (Python/Poetry) Installation ---
echo "--- 2/5: Installation der Backend-Abhängigkeiten via Poetry ---"
# Bereinigung und Installation
poetry env remove python || true
poetry cache clear --all pypi
poetry install

# --- 3. Frontend (npm) Installation ---
echo "--- 3/5: Installation der Frontend-Abhängigkeiten via npm ---"
cd "$PROJECT_ROOT/app/frontend"
npm install
cd "$PROJECT_ROOT" # Zurück zum Wurzelverzeichnis

# --- 4. Wichtige Code-Korrektur (Case-Sensitivity Fix für Linux) ---
echo "--- 4/5: Anwenden des Case-Sensitivity-Fixes für App.tsx ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"

# Korrektur des fehlerhaften Imports (layout -> Layout.tsx)
if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Applying fix: './components/layout' -> './components/Layout.tsx'"
    # Verwendung von sed zum Ersetzen (funktioniert auf den meisten Linux-Distributionen)
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
else
    echo "Fix already applied or import structure changed."
fi


# --- 5. Start der Dienste in TMUX ---
echo "--- 5/5: Starten der Dienste in der Tmux-Sitzung '$TMUX_SESSION' ---"

# Prüfen, ob die Sitzung bereits existiert
tmux has-session -t "$TMUX_SESSION" 2>/dev/null

if [ $? != 0 ]; then
    echo "Starte neue Tmux-Sitzung: $TMUX_SESSION"
    tmux new-session -d -s "$TMUX_SESSION"
    
    # Fenster 0: Backend starten (API)
    tmux send-keys -t "$TMUX_SESSION:0" "cd $PROJECT_ROOT" C-m
    # Host 0.0.0.0 ist wichtig für den Zugriff von extern (nicht nur 127.0.0.1)
    tmux send-keys -t "$TMUX_SESSION:0" "poetry run uvicorn app.backend.main:app --host 0.0.0.0 --reload" C-m
    tmux rename-window -t "$TMUX_SESSION:0" "Backend-API (8000)"

    # Neues Fenster 1: Frontend starten (UI)
    tmux new-window -t "$TMUX_SESSION:1" -n "Frontend-UI (5173)"
    tmux send-keys -t "$TMUX_SESSION:1" "cd $PROJECT_ROOT/app/frontend" C-m
    # --host 0.0.0.0 ist wichtig für den Zugriff von extern
    tmux send-keys -t "$TMUX_SESSION:1" "npm run dev -- --host 0.0.0.0" C-m
    
    echo "========================================================"
    echo "✅ INSTALLATION UND START ERFOLGREICH!"
    echo "Frontend-UI ist verfügbar unter: http://[Ihre VM-IP-Adresse]:5173"
    echo "Backend-API (Docs) ist verfügbar unter: http://[Ihre VM-IP-Adresse]:8000/docs"
    echo "--------------------------------------------------------"
    echo "Wechsle nun zur Tmux-Sitzung. Drücken Sie 'Strg+B, N/P' zum Wechseln."
    
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits. Verbinde neu."
fi

# Sitzung wieder aufnehmen
tmux attach -t "$TMUX_SESSION"
