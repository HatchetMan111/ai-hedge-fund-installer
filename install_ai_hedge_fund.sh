#!/bin/bash
#
# FILE: install_ai_hedge_fund_FINAL_V5_STABILITY.sh
# KRITISCH VERBESSERTE VERSION
# Fokussiert auf die stabile Ausführung und Fehlerbehandlung des Downloads (umgeht Git).
#
set -e

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
# Name des Verzeichnisses, das nach dem Entpacken entsteht (oft 'RepoName-master')
TEMP_DIR_NAME="ai-hedge-fund-master"
ZIP_FILE="$TEMP_DIR_NAME.zip"
TMUX_SESSION="ai_hedge_fund_session"
# URL für den Master-Branch-Download (um Git-Authentifizierung zu vermeiden)
REPO_ZIP_URL="https://github.com/HatchetMan111/ai-hedge-fund/archive/refs/heads/master.zip"
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      🚀 AI Hedge Fund - FINALER Versuch V5: Stabile Ausführung"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
# Leitet stdout und stderr an die Konsole und die Log-Datei um
exec > >(tee -a "$LOG_FILE") 2>&1

# --- GLOBALE PATH-Anpassung ---
export PATH="$HOME/.local/bin:$PATH"

# --- 1. System-Vorbereitung ---
echo "--- 1/8: Installation der System-Abhängigkeiten ---"
# Wir stellen sicher, dass 'unzip' und 'openssl' installiert sind
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git unzip openssl

# Node.js LTS 20 installieren (übersprungen, wenn vorhanden)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js (Version: $(node -v)) bereits installiert."
fi
echo "System-Abhängigkeiten geprüft."

# --- 2. Poetry-Installation ---
echo "--- 2/8: Installation von Poetry ---"
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
fi
echo "Poetry bereit."

# --- 3. Klonen des Repositories (KRITISCHER FIX: ZIP-DOWNLOAD MIT PRÜFUNG) ---
echo "--- 3/8: Download des Projekt-Repositories per ZIP-Archiv (mit Stabilitäts-Check) ---"

# Bereinigen alter Reste
if [ -d "$PROJECT_DIR" ]; then 
    echo "Lösche altes '$PROJECT_DIR' Verzeichnis."
    rm -rf "$PROJECT_DIR"; 
fi
if [ -d "$TEMP_DIR_NAME" ]; then rm -rf "$TEMP_DIR_NAME"; fi
if [ -f "$ZIP_FILE" ]; then rm -f "$ZIP_FILE"; fi

# 1. Download der ZIP-Datei
echo "Downloade ZIP von $REPO_ZIP_URL..."
# -f: scheitert leise bei Serverfehlern; -s: still; -S: zeigt Fehler an; -L: folgt Weiterleitungen
if ! curl -fsSL "$REPO_ZIP_URL" -o "$ZIP_FILE"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: CURL-FEHLER BEIM DOWNLOAD !!!"
    echo "Prüfen Sie Ihre Internetverbindung und Firewall/Proxy."
    echo "--------------------------------------------------------"
    exit 1
fi

# 2. KRITISCHE PRÜFUNG: Ist die Datei gültig?
# '-s' prüft, ob die Datei größer als 0 Bytes ist
if [ ! -f "$ZIP_FILE" ] || [ ! -s "$ZIP_FILE" ]; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: UNGÜLTIGE DOWNLOAD-DATEI !!!"
    echo "Die Datei '$ZIP_FILE' existiert nicht oder ist leer (0 Bytes)."
    echo "Dies deutet auf eine lokale Netzwerkblockade hin, die den Download unterbricht."
    echo "Bitte die Datei manuell herunterladen und per SFTP/SCP hochladen!"
    echo "--------------------------------------------------------"
    exit 1
fi

# 3. Entpacken des Archivs
echo "Entpacke Archiv: $ZIP_FILE..."
if ! unzip "$ZIP_FILE"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: ENTPACKEN FEHLGESCHLAGEN !!!"
    echo "Die heruntergeladene Datei ist beschädigt. **Download-Schritt 1 oder 2 ist fehlgeschlagen.**"
    echo "--------------------------------------------------------"
    exit 1
fi

# 4. Umbenennen und Bereinigen
mv "$TEMP_DIR_NAME" "$PROJECT_DIR"
rm "$ZIP_FILE"

cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)
echo "Download und Entpacken erfolgreich. Aktuelles Verzeichnis: $PROJECT_ROOT"

# --- 4. Projekt-Abhängigkeiten installieren ---
echo "--- 4/8: Installation der Backend & Frontend Abhängigkeiten ---"

echo "-> Installation Backend (Poetry)..."
poetry lock --no-update # Stellt sicher, dass das Lock-File aktuell ist
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT"

# --- 5. Fix für Case-Sensitivity ---
echo "--- 5/8: Anwenden des notwendigen Fixes für den Layout.tsx-Import ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"
if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an..."
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
else
    echo "Fix ist bereits angewandt oder nicht nötig."
fi

# --- 6. KRITISCHER FIX: .env-Datei und DB-Setup ---
echo "--- 6/8: Erstellung der kritischen Backend-Konfiguration (.env) und DB-Migration ---"
ENV_FILE="$PROJECT_ROOT/.env"
# Generiert einen sicheren, zufälligen Schlüssel, der für JWTs benötigt wird.
JWT_SECRET=$(openssl rand -base64 32)
cat << EOF > "$ENV_FILE"
# WICHTIG: SECRET_KEY behebt den Anmeldefehler in der UI!
SECRET_KEY="$JWT_SECRET"
DATABASE_URL="sqlite:///./sql_app.db"
EOF
echo ".env-Datei mit zufälligem SECRET_KEY erstellt."

echo "-> Führe Alembic-Datenbankmigrationen aus..."
poetry run alembic upgrade head
echo "Datenbankmigrationen erfolgreich abgeschlossen."

# --- 7. Bereinigung ---
echo "--- 7/8: Bereinigung (Löschen von SQLite-Datei, falls schon vorhanden) ---"
# Entfernt eine möglicherweise fehlerhafte DB aus einem früheren Lauf.
rm -f "$PROJECT_ROOT/sql_app.db"

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
