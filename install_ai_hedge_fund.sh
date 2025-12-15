#!/bin/bash
#
# FILE: install_ai_hedge_fund_FINAL_V5_STABILITY.sh
# KRITISCH VERBESSERTE VERSION
# Fokussiert auf die stabile Ausführung und Fehlerbehandlung des Downloads.
#
set -e

# --- KONFIGURATION ---
PROJECT_DIR="ai-hedge-fund"
TEMP_DIR_NAME="ai-hedge-fund-master"
ZIP_FILE="$TEMP_DIR_NAME.zip"
TMUX_SESSION="ai_hedge_fund_session"
# URL für den Master-Branch-Download
REPO_ZIP_URL="https://github.com/HatchetMan111/ai-hedge-fund/archive/refs/heads/master.zip"
LOG_FILE="$HOME/ai_hedge_fund_setup.log"

echo "========================================================"
echo "      🚀 AI Hedge Fund - FINALER Versuch V5: Stabile Ausführung"
echo "========================================================"
echo "Alle Schritte werden in $LOG_FILE protokolliert."
exec > >(tee -a "$LOG_FILE") 2>&1

# --- GLOBALE PATH-Anpassung ---
export PATH="$HOME/.local/bin:$PATH"

# --- 1. System-Vorbereitung ---
echo "--- 1/8: Installation der System-Abhängigkeiten ---"
sudo apt update
sudo apt install -y build-essential python3-dev curl tmux git unzip openssl -y

# Node.js LTS 20 installieren (übersprungen, wenn vorhanden)
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
echo "System-Abhängigkeiten geprüft."

# --- 2. Poetry-Installation ---
# ... (wie vorher)
echo "Poetry bereit."

# --- 3. Klonen des Repositories (KRITISCHER FIX: ZIP-DOWNLOAD MIT PRÜFUNG) ---
echo "--- 3/8: Download des Projekt-Repositories per ZIP-Archiv (mit Stabilitäts-Check) ---"

# Bereinigen alter Reste
if [ -d "$PROJECT_DIR" ]; then rm -rf "$PROJECT_DIR"; fi
if [ -d "$TEMP_DIR_NAME" ]; then rm -rf "$TEMP_DIR_NAME"; fi
if [ -f "$ZIP_FILE" ]; then rm -f "$ZIP_FILE"; fi

# 1. Download der ZIP-Datei
echo "Downloade ZIP von $REPO_ZIP_URL..."
# -f: scheitert leise bei Serverfehlern
# -s: still (versteckt Progress Bar)
# -S: zeigt Fehler an, auch wenn -s gesetzt ist
# -L: folgt Weiterleitungen
if ! curl -fsSL "$REPO_ZIP_URL" -o "$ZIP_FILE"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: CURL-FEHLER BEIM DOWNLOAD !!!"
    echo "Prüfen Sie Ihre Internetverbindung und Firewall/Proxy."
    echo "--------------------------------------------------------"
    exit 1
fi

# 2. KRITISCHE PRÜFUNG: Ist die Datei gültig?
if [ ! -f "$ZIP_FILE" ] || [ ! -s "$ZIP_FILE" ]; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: UNGÜLTIGE DOWNLOAD-DATEI !!!"
    echo "Die Datei '$ZIP_FILE' existiert nicht oder ist leer (0 Bytes)."
    echo "Dies deutet auf eine lokale Netzwerkblockade hin."
    echo "VERSUCHEN SIE, die URL in Ihrem Browser herunterzuladen und die Datei manuell auf den Server zu laden."
    echo "URL: $REPO_ZIP_URL"
    echo "--------------------------------------------------------"
    exit 1
fi

# 3. Entpacken des Archivs
echo "Entpacke Archiv: $ZIP_FILE..."
if ! unzip "$ZIP_FILE"; then
    echo "--------------------------------------------------------"
    echo "!!! KRITISCHER FEHLER: ENTPACKEN FEHLGESCHLAGEN !!!"
    echo "Die heruntergeladene Datei ist beschädigt. Das liegt am Netzwerk."
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
echo "-> Installation Backend (Poetry)..."
poetry lock --no-update
poetry install

echo "-> Installation Frontend (npm)..."
cd app/frontend
npm install
cd "$PROJECT_ROOT"

# --- 5. Fix für Case-Sensitivity ---
# ... (wie vorher)

# --- 6. KRITISCHER FIX: .env-Datei und DB-Setup ---
# ... (wie vorher)

# --- 7. Bereinigung ---
# ... (wie vorher)

# --- 8. Start der Dienste in TMUX ---
# ... (wie vorher)

# Sitzung wieder aufnehmen
tmux attach -t "$TMUX_SESSION"
