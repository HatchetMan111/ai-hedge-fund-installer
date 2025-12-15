# AI Hedge Fund Installer

Dieses Repository enthält ein Bash-Skript (`install_ai_hedge_fund.sh`), das die Installation des [ai-hedge-fund](https://github.com/virattt/ai-hedge-fund) Projekts von virattt auf Debian/Ubuntu-basierten Systemen automatisiert. Es ist ideal für die schnelle Einrichtung in einer Proxmox LXC oder VM.
Dazu nutzen Sie am besten die helper scripts um z.B. ein Ubuntu 25.04. bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/ubuntu2504-vm.sh)"
Dannach im Cloud Init Root und Passwort setzen und zudem DHCP oder Ip Adresse vergeben. Dannach Regenerate Image klicken! 
In dieser VM dieses Install Script eingeben! 

## Features

* Aktualisiert das System und installiert benötigte Pakete (git, python3, pip, curl).
* Installiert den Python-Abhängigkeitsmanager [Poetry](https://python-poetry.org/).
* Klont das `ai-hedge-fund`-Repository in Ihr Home-Verzeichnis (`~/ai-hedge-fund`).
* Installiert alle Python-Abhängigkeiten mit Poetry.
* Erstellt eine `.env`-Konfigurationsdatei.

## Verwendung

Sie können das Skript direkt von diesem Repository auf Ihrem Debian/Ubuntu-System (z.B. in einem Proxmox LXC oder einer VM) ausführen.

**Wichtig:** Führen Sie das Skript als normaler Benutzer mit `sudo`-Rechten aus.

1.  **Stellen Sie sicher, dass `wget` oder `curl` installiert ist** (meistens sind sie es, aber falls nicht):
    ```bash
    sudo apt update && sudo apt install -y wget curl
    ```
    
2.  **Führen Sie das Installationsskript aus (empfohlen):**

    **Mit `wget`:**
    ```bash
    wget -qO - https://raw.githubusercontent.com/HatchetMan111/ai-hedge-fund-installer/main/install_ai_hedge_fund.sh(https://raw.githubusercontent.com/HatchetMan111/ai-hedge-fund-installer/main/install_ai_hedge_fund.sh) | bash
    ```
    **Alternativ mit `curl`:**
    ```bash
    curl -sSL [https://raw.githubusercontent.com/HatchetMan111/ai-hedge-fund-installer/main/install_ai_hedge_fund.sh](https://raw.githubusercontent.com/HatchetMan111/ai-hedge-fund-installer/main/install_ai_hedge_fund.sh) | bash
    ```

## Nächste Schritte nach der Installation

Nachdem das Skript erfolgreich ausgeführt wurde:

1.  **Wechseln Sie in das Installationsverzeichnis:**
    ```bash
    cd ~/ai-hedge-fund
    ```

2.  **Bearbeiten Sie die Konfigurationsdatei `.env`:**
    Tragen Sie Ihre API-Schlüssel (mindestens `OPENAI_API_KEY`) ein.
    ```bash
    nano .env
    ```

3.  **Führen Sie die Anwendung aus. Beispiele:**
    * **CLI-Beispiel:**
        ```bash
        poetry run python src/main.py --ticker AAPL,MSFT,NVDA
        ```
    * **Web-App (siehe Original-Repo für Details):**
        ```bash
        poetry run streamlit run src/web_app.py
        ```

## Haftungsausschluss

Dieses Skript wird "wie besehen" zur Verfügung gestellt und hat keinen Bezug zum ursprünglichen `ai-hedge-fund`-Projekt. Verwenden Sie es auf eigenes Risiko. Überprüfen Sie immer den Inhalt von Skripten, die Sie aus dem Internet herunterladen und ausführen.
