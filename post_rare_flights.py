#!/usr/bin/env python3
import sqlite3
import json
import requests
from bs4 import BeautifulSoup
from datetime import datetime, timedelta
import os

# === Carica config ===
with open('/home/pi/flight_tracker/config.json', 'r') as cfg_file:
    config = json.load(cfg_file)

DB_PATH = config.get("db_path", "/home/pi/flight_tracker/adsb.db")
TELEGRAM_TOKEN = config.get("telegram_token")
TELEGRAM_CHAT_ID = config.get("telegram_chat_id")

# === Carica patterns callsign e hex prefix ===
CALLSIGN_PATTERNS_FILE = "/home/pi/flight_tracker/callsign_patterns.txt"
HEX_PREFIXES_FILE = "/home/pi/flight_tracker/hex_prefixes.txt"

def load_patterns(file_path):
    if os.path.exists(file_path):
        with open(file_path, 'r') as f:
            return [line.strip().upper() for line in f if line.strip()]
    return []

callsign_patterns = load_patterns(CALLSIGN_PATTERNS_FILE)
hex_prefixes = load_patterns(HEX_PREFIXES_FILE)

# File per tracciare i voli già postati
POSTED_FILE = "/home/pi/flight_tracker/posted_flights.json"
if not os.path.exists(POSTED_FILE):
    with open(POSTED_FILE, 'w') as f:
        json.dump([], f)

with open(POSTED_FILE, 'r') as f:
    posted_flights = set(json.load(f))

# === Funzione rarità in base al seen_count ===
def get_rarity(seen_count):
    if seen_count == 1:
        return "mythic"
    elif seen_count == 2:
        return "epic"
    elif seen_count == 3:
        return "legendary"
    else:
        return "common"

# === Scraping info volo da adsb.fi ===
def scrape_flight_info(hex_code):
    url = f"https://globe.adsb.fi/?icao={hex_code}"
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
    except Exception as e:
        print(f"Errore nel recupero dati per {hex_code}: {e}")
        return None, None, url

    soup = BeautifulSoup(resp.text, 'html.parser')
    title = soup.find("title").get_text(strip=True) if soup.find("title") else None
    img_tag = soup.find("img", src=lambda s: s and ("aircraft" in s or "photo" in s))
    photo_url = None
    if img_tag:
        photo_url = img_tag['src']
        if photo_url.startswith("//"):
            photo_url = "https:" + photo_url
        elif photo_url.startswith("/"):
            photo_url = "https://globe.adsb.fi" + photo_url

    return title, photo_url, url

# === Funzione invio messaggio Telegram ===
def send_telegram_message(message, photo_url=None):
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT_ID:
        print("Token o chat_id Telegram mancanti in config.json")
        return

    if photo_url:
        try:
            photo_data = requests.get(photo_url, timeout=10).content
            files = {"photo": ("aircraft.jpg", photo_data)}
            data = {"chat_id": TELEGRAM_CHAT_ID, "caption": message}
            url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendPhoto"
            requests.post(url, data=data, files=files)
            print("Messaggio con foto inviato su Telegram.")
            return
        except Exception as e:
            print(f"Errore invio foto: {e}")

    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    try:
        requests.post(url, data={"chat_id": TELEGRAM_CHAT_ID, "text": message})
        print("Messaggio inviato su Telegram.")
    except Exception as e:
        print(f"Errore invio Telegram: {e}")

# === Calcolo data di ieri ===
yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
yesterday_display = (datetime.now() - timedelta(days=1)).strftime("%d.%m.%Y")

# === Connessione DB ===
conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

cursor.execute("""
    SELECT hex, flight, seen_count, last_seen
    FROM adsb_contacts
    WHERE date(last_seen) = ?
""", (yesterday,))

rows = cursor.fetchall()

for hex_code, flight, seen_count, last_seen in rows:
    rarity = get_rarity(seen_count)

    # Solo voli rari
    if seen_count <= 3:
        # Controllo pattern militari
        match_callsign = any(flight.upper().startswith(p) for p in callsign_patterns if flight)
        match_hex = any(hex_code.upper().startswith(p) for p in hex_prefixes)

        if not (match_callsign or match_hex):
            continue

        if hex_code in posted_flights:
            continue  # già postato

        _, photo_url, info_url = scrape_flight_info(hex_code)

        message = (
            f'{yesterday_display}: contatto di rarità livello "{rarity}" (loggato {seen_count} volte) '
            f'registrato dalla mia locale stazione ricevente ADS-B:\n'
            f'#{hex_code} #{flight or "N/A"} - last contact: {last_seen}\n'
            f'{info_url}'
        )

        send_telegram_message(message, photo_url)
        posted_flights.add(hex_code)

# Salva elenco voli già postati
with open(POSTED_FILE, 'w') as f:
    json.dump(list(posted_flights), f)

conn.close()
