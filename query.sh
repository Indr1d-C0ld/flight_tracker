#!/bin/bash

# Percorso al database SQLite
DB_PATH="/home/pi/data.db"

# Percorsi ai file referenza per HEX e Callsign militari
HEX_PREFIX_FILE="hex_prefixes.txt"
CALLSIGN_PATTERN_FILE="callsign_patterns.txt"

# Funzioni di ricerca
search_by_hex() {
    echo "Inserisci il codice HEX da cercare:"
    read hex_input
    [[ -z "$hex_input" ]] && { echo "Errore: non hai inserito un codice HEX."; return; }
    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE hex LIKE '$hex_input%' ORDER BY last_updated ASC;" | less
}

search_by_callsign() {
    echo "Inserisci il callsign da cercare:"
    read callsign_input
    [[ -z "$callsign_input" ]] && { echo "Errore: non hai inserito un callsign."; return; }
    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE callsign LIKE '$callsign_input%' ORDER BY last_updated ASC;" | less
}

# Sottomenu per ricerca specifica
show_search_menu() {
    while true; do
        echo "============================="
        echo "      Ricerca Specifica"
        echo "============================="
        echo "1. Cerca per HEX"
        echo "2. Cerca per Callsign"
        echo "3. Torna al menu principale"
        echo "============================="
        read -p "Scegli un'opzione: " search_choice

        case $search_choice in
            1) search_by_hex ;;
            2) search_by_callsign ;;
            3) break ;;
            *) echo "Opzione non valida. Riprova." ;;
        esac
        echo "Premi INVIO per continuare..."
        read
    done
}

filter_by_date() {
    echo "Inserisci la data (formato YYYY-MM-DD):"
    read date_input
    [[ -z "$date_input" ]] && { echo "Errore: non hai inserito una data valida."; return; }

    echo "============================="
    echo "  Ordinamento Risultati"
    echo "============================="
    echo "1. Ordina per HEX (alfabetico)"
    echo "2. Ordina per Callsign (alfabetico)"
    echo "3. Ordina per Data (cronologico)"
    echo "============================="
    read -p "Scegli un'opzione: " order_choice

    case $order_choice in
        1)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE last_updated LIKE '$date_input%' ORDER BY hex ASC;" | less
            ;;
        2)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE last_updated LIKE '$date_input%' ORDER BY callsign ASC;" | less
            ;;
        3)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE last_updated LIKE '$date_input%' ORDER BY last_updated ASC;" | less
            ;;
        *)
            echo "Opzione non valida."
            ;;
    esac
}

# Funzioni Classifiche
top_10_callsigns() {
    sqlite3 -header -column $DB_PATH "SELECT callsign, COUNT(*) AS count FROM flights WHERE callsign IS NOT NULL AND callsign != '' GROUP BY callsign ORDER BY count DESC LIMIT 10;" | less
}

highest_altitude() {
    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE altitude > 0 AND altitude != 'ground' AND hex NOT LIKE '~%' ORDER BY altitude DESC, last_updated ASC LIMIT 10;" | less
}

highest_speed() {
    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE hex NOT LIKE '~%' ORDER BY speed DESC LIMIT 10;" | less
}

# Sottomenu Classifiche
show_rankings_menu() {
    while true; do
        echo "============================="
        echo "         Classifiche"
        echo "============================="
        echo "1. Top 10 Callsign"
        echo "2. Top 10 Altitudine"
        echo "3. Top 10 Velocità"
        echo "4. Torna al menu principale"
        echo "============================="
        read -p "Scegli un'opzione: " rankings_choice

        case $rankings_choice in
            1) top_10_callsigns ;;
            2) highest_altitude ;;
            3) highest_speed ;;
            4) break ;;
            *) echo "Opzione non valida. Riprova." ;;
        esac
    done
}

ground_flights() {
    echo "=============================="
    echo "     Ordinamento Voli a Terra"
    echo "=============================="
    echo "1. Ordina per Data (dal più vecchio)"
    echo "2. Ordina per HEX (alfabetico)"
    echo "3. Ordina per Callsign (alfabetico)"
    echo "=============================="
    read -p "Scegli un'opzione: " order_choice

    case $order_choice in
        1) 
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE altitude = 'ground' AND hex NOT LIKE '~%' ORDER BY last_updated ASC;" | less
            ;;
        2)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE altitude = 'ground' AND hex NOT LIKE '~%' ORDER BY hex ASC;" | less
            ;;
        3)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE altitude = 'ground' AND hex NOT LIKE '~%' ORDER BY callsign ASC;" | less
            ;;
        *)
            echo "Opzione non valida. Riprova."
            ;;
    esac
}

emergency_squawk() {
    echo "=================================="
    echo "  Ordinamento Voli con Squawk d'Emergenza"
    echo "=================================="
    echo "1. Ordina per Data (dal più vecchio)"
    echo "2. Ordina per HEX (alfabetico)"
    echo "3. Ordina per Callsign (alfabetico)"
    echo "=================================="
    read -p "Scegli un'opzione: " order_choice

    case $order_choice in
        1)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE squawk IN ('7500', '7600', '7700') AND hex NOT LIKE '~%' ORDER BY last_updated ASC;" | less
            ;;
        2)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE squawk IN ('7500', '7600', '7700') AND hex NOT LIKE '~%' ORDER BY hex ASC;" | less
            ;;
        3)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE squawk IN ('7500', '7600', '7700') AND hex NOT LIKE '~%' ORDER BY callsign ASC;" | less
            ;;
        *)
            echo "Opzione non valida. Riprova."
            ;;
    esac
}

find_military_flights() {
    hex_query=$(awk '{print "hex LIKE \x27"$1"%\x27 OR "}' $HEX_PREFIX_FILE | sed '$ s/ OR $//')
    callsign_query=$(awk '{print "callsign LIKE \x27"$1"%\x27 OR "}' $CALLSIGN_PATTERN_FILE | sed '$ s/ OR $//')

    echo "============================="
    echo "  Ordinamento Voli Militari"
    echo "============================="
    echo "1. Ordina per Data (dal più vecchio)"
    echo "2. Ordina per HEX (alfabetico)"
    echo "3. Ordina per Callsign (alfabetico)"
    echo "4. Seleziona un giorno specifico"
    echo "============================="
    read -p "Scegli un'opzione: " order_choice

    case $order_choice in
        1)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE ($hex_query) OR ($callsign_query) ORDER BY last_updated ASC;" | less
            ;;
        2)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE ($hex_query) OR ($callsign_query) ORDER BY hex ASC;" | less
            ;;
        3)
            sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE ($hex_query) OR ($callsign_query) ORDER BY callsign ASC;" | less
            ;;
        4)
            echo "Inserisci la data (formato YYYY-MM-DD):"
            read date_input
            [[ -z "$date_input" ]] && { echo "Errore: non hai inserito una data valida."; return; }
            echo "============================="
            echo "  Ordinamento Risultati"
            echo "============================="
            echo "1. Ordina per HEX (alfabetico)"
            echo "2. Ordina per Callsign (alfabetico)"
            echo "3. Ordina per Data (cronologico)"
            echo "============================="
            read -p "Scegli un'opzione: " sub_order_choice
            case $sub_order_choice in
                1)
                    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE last_updated LIKE '$date_input%' AND (($hex_query) OR ($callsign_query)) ORDER BY hex ASC;" | less
                    ;;
                2)
                    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE last_updated LIKE '$date_input%' AND (($hex_query) OR ($callsign_query)) ORDER BY callsign ASC;" | less
                    ;;
                3)
                    sqlite3 -header -column $DB_PATH "SELECT * FROM flights WHERE last_updated LIKE '$date_input%' AND (($hex_query) OR ($callsign_query)) ORDER BY last_updated ASC;" | less
                    ;;
                *)
                    echo "Opzione non valida."
                    ;;
            esac
            ;;
        *)
            echo "Opzione non valida."
            ;;
    esac
}

search_api() {
    while true; do
        echo "=============================="
        echo "  Ricerca Online (API adsb.fi)"
        echo "=============================="
        echo "1. Cerca per HEX"
        echo "2. Cerca per Callsign"
        echo "3. Cerca per Registrazione"
        echo "4. Torna al menu principale"
        echo "=============================="
        read -p "Scegli un'opzione: " api_choice

        case $api_choice in
            1) 
                echo "Inserisci il codice HEX da cercare:"
                read hex
                [[ -z "$hex" ]] && { echo "Errore: non hai inserito un codice HEX."; continue; }
                curl -s "https://opendata.adsb.fi/api/v2/hex/$hex" | jq -r '
                .ac[] | "Hex: \(.hex)\nFlight: \(.flight)\nRegistration: \(.r)\nDescription: \(.desc)\nCategory: \(.category)\n"' ;;
            2) 
                echo "Inserisci il callsign da cercare:"
                read callsign
                [[ -z "$callsign" ]] && { echo "Errore: non hai inserito un callsign."; continue; }
                curl -s "https://opendata.adsb.fi/api/v2/callsign/$callsign" | jq -r '
                .ac[] | "Hex: \(.hex)\nFlight: \(.flight)\nRegistration: \(.r)\nDescription: \(.desc)\nCategory: \(.category)\n"' ;;
            3)
                echo "Inserisci la registrazione da cercare:"
                read reg
                [[ -z "$reg" ]] && { echo "Errore: non hai inserito una registrazione."; continue; }
                curl -s "https://opendata.adsb.fi/api/v2/registration/$reg" | jq -r '
                .ac[] | "Hex: \(.hex)\nFlight: \(.flight)\nRegistration: \(.r)\nDescription: \(.desc)\nCategory: \(.category)\n"' ;;
            4) break ;;
            *) echo "Opzione non valida. Riprova." ;;
        esac
    done
}

database_statistics() {
    echo "=============================="
    echo "       Statistiche Database"
    echo "=============================="

    # Calcola il numero di HEX univoci
    unique_hex=$(sqlite3 $DB_PATH "SELECT COUNT(DISTINCT hex) FROM flights WHERE hex NOT LIKE '~%';")

    # Calcola altitudine media
    avg_altitude=$(sqlite3 $DB_PATH "SELECT AVG(altitude) FROM flights WHERE altitude > 0 AND altitude != 'ground' AND hex NOT LIKE '~%';")
    avg_altitude=${avg_altitude:-0}  # Se null, imposta a 0
    avg_altitude=$(echo "$avg_altitude" | cut -d '.' -f 1)  # Rimuovi parte decimale

    # Calcola velocità media
    avg_speed=$(sqlite3 $DB_PATH "SELECT AVG(speed) FROM flights WHERE speed > 0 AND hex NOT LIKE '~%';")
    avg_speed=${avg_speed:-0}  # Se null, imposta a 0
    avg_speed=$(echo "$avg_speed" | cut -d '.' -f 1)  # Rimuovi parte decimale

    # Ottieni la dimensione del database
    db_size=$(du -h $DB_PATH | awk '{print $1}')

    # Visualizza i risultati
    echo "Numero di HEX univoci salvati: $unique_hex"
    echo "Altitudine media: $(printf "%.0f" $avg_altitude) piedi"
    echo "Velocità media: $(printf "%.0f" $avg_speed) nodi"
    echo "Dimensione del database: $db_size"

    echo "=============================="
}

info_hardware() {
    echo "============================="
    echo "         Info Hardware"
    echo "============================="
    echo "$(lscpu | grep 'CPU max MHz:' | tr -d '[:space:]')"
    echo "$(lscpu | grep 'scaling MHz:' | tr -d '[:space:]')"
    echo "Tipo di Processore: $(lscpu | grep 'Model name:' | sed 's/Model name: *//')"
    echo "Temperatura CPU: $(vcgencmd measure_temp | sed 's/temp=//')"
    echo "Spazio su disco occupato: $(df -h / | awk 'NR==2 {print $3}')"
    echo "Spazio su disco disponibile: $(df -h / | awk 'NR==2 {print $4}')"
    echo "RAM in uso: $(free -h | awk '/Mem:/ {print $3}')"
    echo "RAM disponibile: $(free -h | awk '/Mem:/ {print $7}')"
    echo "Uptime sistema: $(uptime -p)"
    echo "============================="
}

# Menu principale
while true; do
    echo "============================="
    echo "       Flight Tracker"
    echo "============================="
    echo "1. Ricerca Specifica"
    echo "2. Filtra per Data"
    echo "3. Voli a Terra"
    echo "4. Voli con Squawk d'Emergenza"
    echo "5. Isola Voli Militari"
    echo "6. Classifiche"
    echo "7. Ricerca Online (adsb.fi)"
    echo "8. Statistiche Database"
    echo "9. Info Hardware"
    echo "0. Esci"
    echo "============================="
    read -p "Scegli un'opzione: " main_choice

    case $main_choice in
        1) show_search_menu ;;
        2) filter_by_date ;;
        3) ground_flights ;;
        4) emergency_squawk ;;
        5) find_military_flights ;;
        6) show_rankings_menu ;;
        7) search_api ;;
        8) database_statistics ;;
        9) info_hardware ;;
        0) echo "Uscita in corso..."; break ;;
        *) echo "Opzione non valida. Riprova." ;;
    esac
done

