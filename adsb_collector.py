#!/usr/bin/env python3

import requests
import datetime
import sqlite3
import os

# Path del tuo database SQLite
DB_PATH = "/home/pi/flight_tracker/adsb.db"

# Endpoint (o file) di tar1090 che restituisce il JSON degli aerei
TAR1090_URL = "http://192.168.178.30/tar1090/data/aircraft.json"

def create_table_if_not_exists(conn):
    """
    Crea la tabella adsb_contacts se non esiste già,
    includendo la colonna last_count_date per il conteggio giornaliero.
    """
    conn.execute("""
    CREATE TABLE IF NOT EXISTS adsb_contacts (
        hex TEXT PRIMARY KEY,
        flight TEXT,
        squawk TEXT,
        speed INTEGER,
        altitude INTEGER,
        first_seen DATETIME NOT NULL,
        last_seen DATETIME NOT NULL,
        seen_count INTEGER NOT NULL DEFAULT 1,
        last_count_date TEXT  -- data dell'ultimo incremento di count (formato YYYY-MM-DD)
    );
    """)
    conn.commit()

def get_adsb_data(url):
    """
    Scarica i dati JSON da tar1090 (o da un file locale).
    """
    response = requests.get(url)
    data = response.json()
    return data

def upsert_adsb_contact(conn, hex_code, flight, squawk_code, speed, altitude):
    """
    Esegue l'upsert del contatto ADS-B in SQLite:
      - Se l'hex non esiste, inserisce un nuovo record con seen_count=1 (prima volta).
      - Se l'hex esiste, aggiorna i campi e:
         * Se last_count_date != data odierna, incrementa seen_count e last_count_date.
         * Altrimenti non incrementa.
    """
    now_str = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    today_str = datetime.date.today().isoformat()  # "YYYY-MM-DD"

    # Inserimento con ON CONFLICT
    sql = """
    INSERT INTO adsb_contacts (
        hex, flight, squawk, speed, altitude, first_seen, last_seen, seen_count, last_count_date
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
    ON CONFLICT(hex) DO UPDATE SET
        flight    = excluded.flight,
        squawk    = excluded.squawk,
        speed     = excluded.speed,
        altitude  = excluded.altitude,
        last_seen = excluded.last_seen,

        seen_count = CASE
            WHEN adsb_contacts.last_count_date <> ?
            THEN adsb_contacts.seen_count + 1
            ELSE adsb_contacts.seen_count
        END,

        last_count_date = CASE
            WHEN adsb_contacts.last_count_date <> ?
            THEN excluded.last_count_date
            ELSE adsb_contacts.last_count_date
        END
    """

    conn.execute(sql, (
        hex_code,
        flight,
        squawk_code,
        speed,
        altitude,
        now_str,
        now_str,
        today_str,    # last_count_date (in caso di nuova inserzione)

        today_str,    # 1° per CASE (seen_count)
        today_str     # 2° per CASE (last_count_date)
    ))

def main():
    # Connessione (o creazione) del DB SQLite
    conn = sqlite3.connect(DB_PATH)

    # Crea la tabella se non esiste già (con last_count_date)
    create_table_if_not_exists(conn)

    # Scarica i dati da tar1090
    adsb_data = get_adsb_data(TAR1090_URL)

    # Itera sugli aerei
    aircraft_list = adsb_data.get("aircraft", [])
    for aircraft in aircraft_list:
        # Estrai i campi desiderati, gestendo eventuali mancanze
        hex_code = aircraft.get("hex")
        flight   = aircraft.get("flight", "").strip()
        squawk_code = aircraft.get("squawk", "")

        # In tar1090/readsb, la velocità spesso è 'gs' (ground speed).
        speed_val = aircraft.get("gs", 0)

        # Altitudine barometrica 'alt_baro'
        altitude_val = aircraft.get("alt_baro", 0)

        if not hex_code:
            continue  # salta se manca il codice hex

        # Effettua l'upsert con logica "conteggio giornaliero"
        upsert_adsb_contact(conn, hex_code, flight, squawk_code, speed_val, altitude_val)

    # Salva le modifiche e chiudi
    conn.commit()
    conn.close()

if __name__ == "__main__":
    main()

