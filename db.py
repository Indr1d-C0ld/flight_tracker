import requests
import sqlite3
import json
from datetime import datetime

# Configurazioni
TAR1090_URL = "http://192.168.178.30/tar1090/data/aircraft.json"  # URL del JSON di tar1090
DB_PATH = "/home/pi/data.db"  # Percorso locale al database remoto

def fetch_data():
    try:
        response = requests.get(TAR1090_URL)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Errore nel recupero dei dati: {e}")
        return None

def process_and_save(data):
    if not data or "aircraft" not in data:
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Creazione della tabella se non esiste
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS flights (
            hex TEXT PRIMARY KEY,
            callsign TEXT,
            altitude INTEGER,
            speed INTEGER,
            squawk TEXT,
            seen INTEGER,
            last_updated DATETIME
        )
    ''')

    for aircraft in data["aircraft"]:
        hex_code = aircraft.get("hex")
        callsign = aircraft.get("flight", "").strip()
        altitude = aircraft.get("alt_baro")
        speed = aircraft.get("gs")
        squawk = aircraft.get("squawk")
        seen = aircraft.get("seen")
        last_updated = datetime.now()

        if hex_code:
            cursor.execute('''
                INSERT INTO flights (hex, callsign, altitude, speed, squawk, seen, last_updated)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(hex) DO UPDATE SET
                    callsign=excluded.callsign,
                    altitude=excluded.altitude,
                    speed=excluded.speed,
                    squawk=excluded.squawk,
                    seen=excluded.seen,
                    last_updated=excluded.last_updated
            ''', (hex_code, callsign, altitude, speed, squawk, seen, last_updated))

    conn.commit()
    conn.close()

def main():
    data = fetch_data()
    process_and_save(data)

if __name__ == "__main__":
    main()

