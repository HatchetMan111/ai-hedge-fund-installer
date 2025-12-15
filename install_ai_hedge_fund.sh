#!/bin/bash
#
# FILE: install_ai_hedge_fund_FINAL_V3.sh
# KRITISCH VERBESSERTE VERSION
# Behebt den Anmeldefehler durch Umstellung auf Git Fetch und Checkout statt Clone.
#
set -e

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
TMUX_SESSION="ai_hedge_fund_session"
# Wir verwenden die HTTP-URL, aber holen die Daten manuell.
REPO_URL="https://github.com/HatchetMan111/ai-hedge-fund.git"
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      🚀 AI Hedge Fund - FINALER Versuch: Git-Fix angewandt"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
exec > >(tee -a "$LOG_FILE") 2>&1

# --- GLOBALE PATH-Anpassung ---
export PATH="$HOME/.local/bin:$PATH"

# --- 1. System-Vorbereitung (Unverändert) ---
echo "--- 1/8: Installation der System-Abhängigkeiten ---"
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git -y

if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js (Version: $(node -v)) bereits installiert."
fi

# --- 2. Poetry-Installation (Unverändert) ---
echo "--- 2/8: Installation von Poetry ---"
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3 -
fi
echo "Poetry bereit."

# --- 3. Klonen des Repositories (KRITISCHER FIX) ---
echo "--- 3/8: Klonen des Projekt-Repositories (Umgehung des Anmeldefehlers) ---"

if [ -d "$PROJECT_DIR" ]; then
    echo "Projektverzeichnis '$PROJECT_DIR' existiert. Lösche es für einen sauberen Start."
    rm -rf "$PROJECT_DIR"
fi

mkdir "$PROJECT_DIR"
cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)

echo "Manuelles Initialisieren und Abrufen des Repository-Inhalts..."

# **KRITISCHE NEUE SCHRITTE:**
# 1. Initiiere ein leeres Git-Repo
git init

# 2. Füge die Remote-URL hinzu
git remote add origin "$REPO_URL"

# 3. Hole die Dateien explizit ab (tiefenreduziert, um es schneller zu machen)
# Hier KANN es theoretisch wieder fragen, aber es ist die sauberste Art, den Inhalt zu holen.
# Wenn es hier fehlschlägt, ist das Repository definitiv NICHT öffentlich oder nicht zugänglich.
if ! git fetch --depth 1 origin master; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER BEIM ABRUFEN DER DATEN !!!"
    echo "Wenn Sie diesen Fehler sehen, ist das Repository entweder nicht öffentlich oder Ihre Netzwerk-/Firewall-Konfiguration blockiert Git."
    echo "--------------------------------------------------------"
    exit 1
fi

# 4. Checke den Master-Branch aus
git checkout master
echo "Klonen/Abrufen erfolgreich. Aktuelles Verzeichnis: $PROJECT_ROOT"

# --- 4. Projekt-Abhängigkeiten installieren (Unverändert) ---
echo "--- 4/8: Installation der Backend & Frontend Abhängigkeiten ---"

echo "-> Installation Backend (Poetry)..."
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT"

# --- 5. Fix für Case-Sensitivity (Unverändert) ---
echo "--- 5/8: Anwenden des notwendigen Fixes für den Layout.tsx-Import ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"
if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an..."
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
fi

# --- 6. KRITISCHER FIX: .env-Datei und DB-Setup (Unverändert) ---
echo "--- 6/8: Erstellung der kritischen Backend-Konfiguration (.env) und DB-Migration ---"
ENV_FILE="$PROJECT_ROOT/.env"
JWT_SECRET=$(openssl rand -base64 32)
cat << EOF > "$ENV_FILE"
SECRET_KEY="$JWT_SECRET"
DATABASE_URL="sqlite:///./sql_app.db"
EOF
echo ".env-Datei mit zufälligem SECRET_KEY erstellt."

echo "-> Führe Alembic-Datenbankmigrationen aus..."
# Stelle sicher, dass openssl installiert ist, falls es für den JWT_SECRET fehlt
sudo apt install -y openssl
poetry run alembic upgrade head
echo "Datenbankmigrationen erfolgreich abgeschlossen."

# --- 7. Bereinigung (Unverändert) ---
echo "--- 7/8: Bereinigung (Löschen von SQLite-Datei, falls schon vorhanden) ---"
rm -f "$PROJECT_ROOT/sql_app.db"

# --- 8. Start der Dienste in TMUX (Unverändert) ---
echo "--- 8/8: Starten der Dienste in der Tmux-Sitzung '$TMUX_SESSION' ---"
tmux has-session -t "$TMUX_SESSION" 2>/dev/null

if [ $? != 0 ]; then
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
    echo "✅ INSTALLATION UND START ERFOLGREICH!"
    echo "Frontend-UI: http://[Ihre VM-IP-Adresse]:5173"
    echo "Backend-API: http://[Ihre VM-IP-Adresse]:8000/docs"
    echo "--------------------------------------------------------"
    echo "HINWEIS: Registrieren Sie sich zuerst in der UI!"
    echo "--------------------------------------------------------"
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits. Verbinde neu."
fi

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
