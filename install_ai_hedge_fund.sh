#!/bin/bash
#
# FILE: install_ai_hedge_fund_FINAL.sh
# KRITISCH VERBESSERTE VERSION
# Behebt den Anmeldefehler beim Klonen durch Deaktivierung von Submodul-Klonen.
#
set -e # Beendet das Skript sofort bei einem Fehler

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
TMUX_SESSION="ai_hedge_fund_session"
REPO_URL="https://github.com/HatchetMan111/ai-hedge-fund.git"
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      🚀 AI Hedge Fund - Finales Setup & Start"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
# Leitet stdout und stderr an die Konsole und die Log-Datei um
exec > >(tee -a "$LOG_FILE") 2>&1

# --- GLOBALE PATH-Anpassung für die aktuelle Shell ---
export PATH="$HOME/.local/bin:$PATH"

# --- 1. System-Vorbereitung ---
echo "--- 1/8: Installation der System-Abhängigkeiten ---"
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
echo "--- 2/8: Installation von Poetry ---"
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    echo "Poetry erfolgreich installiert."
else
    echo "Poetry bereits installiert."
fi

# --- 3. Klonen des Repositories (MIT FIX FÜR AUTHENTIFIZIERUNG) ---
echo "--- 3/8: Klonen des Projekt-Repositories (Auth-Fix angewendet) ---"

if [ -d "$PROJECT_DIR" ]; then
    echo "Projektverzeichnis '$PROJECT_DIR' existiert. Lösche es für einen sauberen Klon."
    rm -rf "$PROJECT_DIR"
fi

# **KRITISCHER FIX:** Klonen ohne rekursive Submodule, um die Abfrage nach dem GitHub-Login zu vermeiden.
echo "Starte Klonen von $REPO_URL ohne rekursive Submodule..."
if ! git clone --no-recursive "$REPO_URL"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER BEIM KLONEN !!!"
    echo "Der Klon-Vorgang von $REPO_URL ist fehlgeschlagen. Bitte überprüfen Sie die URL."
    echo "--------------------------------------------------------"
    exit 1
fi

cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)
echo "Klonen erfolgreich. Aktuelles Verzeichnis: $PROJECT_ROOT"

# --- 4. Projekt-Abhängigkeiten installieren ---
echo "--- 4/8: Installation der Backend & Frontend Abhängigkeiten ---"

echo "-> Installation Backend (Poetry)..."
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT"

# --- 5. Fix für Case-Sensitivity (Layout-Import) ---
echo "--- 5/8: Anwenden des notwendigen Fixes für den Layout.tsx-Import ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"

if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an: './components/layout' -> './components/Layout.tsx'"
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
else
    echo "Fix ist bereits angewandt oder Importstruktur wurde geändert."
fi

# --- 6. KRITISCHER FIX: Erstellung der .env-Datei und DB-Setup ---
echo "--- 6/8: Erstellung der kritischen Backend-Konfiguration (.env) und DB-Migration ---"

ENV_FILE="$PROJECT_ROOT/.env"
JWT_SECRET=$(openssl rand -base64 32)

cat << EOF > "$ENV_FILE"
# WICHTIG: SECRET_KEY behebt den Anmeldefehler in der UI!
SECRET_KEY="$JWT_SECRET"
DATABASE_URL="sqlite:///./sql_app.db"
EOF

echo ".env-Datei mit zufälligem SECRET_KEY erstellt und nach $ENV_FILE geschrieben."

echo "-> Führe Alembic-Datenbankmigrationen aus (Erstellung der Datenbankstruktur)..."
poetry run alembic upgrade head
echo "Datenbankmigrationen erfolgreich abgeschlossen."

# --- 7. Bereinigung (optional) ---
echo "--- 7/8: Bereinigung (Löschen von SQLite-Datei, falls schon vorhanden, wird neu erstellt) ---"
# Dies ist nur eine zusätzliche Sicherheit, falls die DB aus einem vorherigen Lauf fehlerhaft war.
rm -f "$PROJECT_ROOT/sql_app.db"
echo "Alte sql_app.db entfernt (wird durch das Backend neu erstellt)."


# --- 8. Start der Dienste in TMUX ---
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
    echo "Frontend-UI ist verfügbar unter: http://[Ihre VM-IP-Adresse]:5173"
    echo "Backend-API (Docs) ist verfügbar unter: http://[Ihre VM-IP-Adresse]:8000/docs"
    echo "--------------------------------------------------------"
    echo "HINWEIS: Sie müssen sich in der UI zuerst registrieren, um einen Benutzer zu erstellen!"
    echo "--------------------------------------------------------"
    
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits. Verbinde neu."
fi

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
