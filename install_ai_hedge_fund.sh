#!/bin/bash
#
# FILE: install_ai_hedge_fund_COMPLETE.sh
# VOLLSTÄNDIG KORRIGIERTE & VERBESSERTE VERSION
# Behebt PATH-Probleme, Klon-Fehler, Layout.tsx-Fix UND den kritischen JWT/DB-Setup-Fehler.
#
set -e # Beendet das Skript sofort bei einem Fehler

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
TMUX_SESSION="ai_hedge_fund_session"
REPO_URL="https://github.com/HatchetMan111/ai-hedge-fund.git"
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      🚀 AI Hedge Fund - Vollständiges Setup & Start"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
# Leitet stdout und stderr an die Konsole und die Log-Datei um
exec > >(tee -a "$LOG_FILE") 2>&1

# --- GLOBALE PATH-Anpassung für die aktuelle Shell ---
# Stellt sicher, dass das lokale Bin-Verzeichnis für Poetry sofort im Pfad ist.
export PATH="$HOME/.local/bin:$PATH"

# --- 1. System-Vorbereitung (apt, Build-Tools, Node.js, Git) ---
echo "--- 1/8: Installation der System-Abhängigkeiten ---"
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

# --- 2. Poetry-Installation ---
echo "--- 2/8: Installation von Poetry (Python-Paketmanager) ---"
if ! command -v poetry &> /dev/null; then
    echo "Installing Poetry..."
    curl -sSL https://install.python-poetry.org | python3 -
    echo "Poetry erfolgreich installiert."
else
    echo "Poetry bereits installiert."
fi

# --- 3. Klonen des Repositories ---
echo "--- 3/8: Klonen des Projekt-Repositories ---"

# Bereinigen alter Reste, falls vorhanden
if [ -d "$PROJECT_DIR" ]; then
    echo "Projektverzeichnis '$PROJECT_DIR' existiert. Lösche es, um einen sauberen Klon zu gewährleisten."
    rm -rf "$PROJECT_DIR"
fi

echo "Starte Klonen von $REPO_URL..."
if ! git clone "$REPO_URL"; then
    echo "!!! KRITISCHER FEHLER BEIM KLONEN !!!"
    exit 1
fi

cd "$PROJECT_DIR"
PROJECT_ROOT=$(pwd)
echo "Klonen erfolgreich. Aktuelles Verzeichnis: $PROJECT_ROOT"

# --- 4. Projekt-Abhängigkeiten installieren ---
echo "--- 4/8: Installation der Backend (Poetry) & Frontend (npm) Abhängigkeiten ---"

echo "-> Installation Backend (Poetry)..."
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT" # Zurück zum Wurzelverzeichnis

# --- 5. Fix für Case-Sensitivity (Layout-Import) ---
echo "--- 5/8: Anwenden des notwendigen Fixes für den Layout.tsx-Import (Linux) ---"
APP_TSX="$PROJECT_ROOT/app/frontend/src/App.tsx"

# Dieser Fix ist notwendig, da das Dateisystem von Linux case-sensitive ist.
if grep -q "import { Layout } from './components/layout';" "$APP_TSX"; then
    echo "Wende Fix an: './components/layout' -> './components/Layout.tsx'"
    # sed-Befehl ersetzt die fehlerhafte Zeile
    sed -i "s|import { Layout } from './components/layout';|import { Layout } from './components/Layout.tsx';|g" "$APP_TSX"
else
    echo "Fix ist bereits angewandt oder Importstruktur wurde geändert."
fi

# --- 6. KRITISCHER FIX: Erstellung der .env-Datei und DB-Setup ---
echo "--- 6/8: Erstellung der kritischen Backend-Konfiguration (.env) und DB-Migration ---"

ENV_FILE="$PROJECT_ROOT/.env"
# Generiert einen sicheren, zufälligen Schlüssel, der für JWTs benötigt wird.
JWT_SECRET=$(openssl rand -base64 32)

cat << EOF > "$ENV_FILE"
# .env-Datei für das FastAPI-Backend
# Die API läuft standardmäßig auf http://0.0.0.0:8000
#
# WICHTIG: Dies behebt den Anmeldefehler!
# Ohne diesen Secret Key kann das Backend keine gültigen JWTs signieren.
SECRET_KEY="$JWT_SECRET"

# Die Datenbank-URL (Standard für SQLite)
DATABASE_URL="sqlite:///./sql_app.db"
EOF

echo ".env-Datei mit zufälligem SECRET_KEY erstellt und nach $ENV_FILE geschrieben."

echo "-> Führe Alembic-Datenbankmigrationen aus (Erstellung der Datenbankstruktur)..."
# Führt Alembic im Poetry-Environment aus, um die Datenbankstruktur zu erstellen
poetry run alembic upgrade head
echo "Datenbankmigrationen erfolgreich abgeschlossen."

# --- 7. Erstellung eines Standard-Benutzers (Optional, aber hilfreich) ---
# Das Repository enthält kein spezielles Skript zur Benutzererstellung.
# Dieser Schritt wird übersprungen, aber der Benutzer muss sich über die UI registrieren,
# sobald diese läuft.

# --- 8. Start der Dienste in TMUX ---
echo "--- 8/8: Starten der Dienste in der Tmux-Sitzung '$TMUX_SESSION' ---"

# Prüfen, ob die Sitzung bereits existiert
tmux has-session -t "$TMUX_SESSION" 2>/dev/null

if [ $? != 0 ]; then
    echo "Starte neue Tmux-Sitzung: $TMUX_SESSION"
    tmux new-session -d -s "$TMUX_SESSION"
    
    # Fenster 0: Backend starten (API - Port 8000)
    tmux send-keys -t "$TMUX_SESSION:0" "cd $PROJECT_ROOT" C-m
    # Start mit Poetry (lädt die .env-Datei)
    tmux send-keys -t "$TMUX_SESSION:0" "poetry run uvicorn app.backend.main:app --host 0.0.0.0 --reload" C-m
    tmux rename-window -t "$TMUX_SESSION:0" "Backend-API (8000)"

    # Neues Fenster 1: Frontend starten (UI - Port 5173)
    tmux new-window -t "$TMUX_SESSION:1" -n "Frontend-UI (5173)"
    tmux send-keys -t "$TMUX_SESSION:1" "cd $PROJECT_ROOT/app/frontend" C-m
    # Startet den Vite-Server
    tmux send-keys -t "$TMUX_SESSION:1" "npm run dev -- --host 0.0.0.0" C-m
    
    echo "========================================================"
    echo "✅ INSTALLATION UND START ERFOLGREICH!"
    echo "Frontend-UI ist verfügbar unter: http://[Ihre VM-IP-Adresse]:5173"
    echo "Backend-API (Docs) ist verfügbar unter: http://[Ihre VM-IP-Adresse]:8000/docs"
    echo "--------------------------------------------------------"
    echo "HINWEIS: Sie müssen sich in der UI zuerst registrieren, um einen Benutzer zu erstellen!"
    echo "--------------------------------------------------------"
    echo "Die Tmux-Sitzung wurde gestartet. Drücken Sie Strg+B, dann [N] oder [P], um zwischen den Fenstern zu wechseln."
    
else
    echo "Tmux-Sitzung '$TMUX_SESSION' existiert bereits. Verbinde neu."
fi

# Sitzung wieder aufnehmen, damit der Benutzer die Logs sieht
tmux attach -t "$TMUX_SESSION"
