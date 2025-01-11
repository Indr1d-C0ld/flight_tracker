#!/bin/bash

###############################################################################
## Configurazioni principali
###############################################################################

DB_PATH="/home/pi/flight_tracker/adsb.db"    # Percorso al DB SQLite
PRINTER_NAME="Canon"                         # Nome della stampante CUPS

HEX_PREFIX_FILE="/home/pi/flight_tracker/hex_prefixes.txt"           # File prefix militari
CALLSIGN_PATTERN_FILE="/home/pi/flight_tracker/callsign_patterns.txt" # File pattern callsign militari

###############################################################################
## Funzione che esegue la query e gestisce:
## - Visualizzazione colorata a schermo (colonne complete, compreso seen_count, rarity)
## - Possibilità di SALVARE o STAMPARE i risultati 
##   * Salva su file => SOLO prime 7 colonne (senza seen_count, rarity)
##   * Stampa        => TUTTE le 9 colonne (incluse seen_count, rarity)
##   Inoltre, rimuoviamo gli apici da first_seen/last_seen anche nel file/stampa.
###############################################################################
query_and_process() {
    local sql="$1"

    # 1. Creiamo un file temporaneo (tmpfile) con TUTTE le colonne (1..9).
    local tmpfile
    tmpfile="$(mktemp)"

    # Eseguiamo la query in CSV e salviamo in tmpfile (tutte le colonne).
    sqlite3 -header -csv "$DB_PATH" "$sql" > "$tmpfile"

    # 2. Mostriamo a schermo con color (display_results_csv), che già rimuove apici su video.
    cat "$tmpfile" | display_results_csv | less -R

    # 3. Chiediamo all'utente se salvare o stampare
    echo
    echo "Vuoi salvare o stampare i risultati estratti?"
    echo "1) Salva su file (prime 7 colonne, senza seen_count né rarity, rimuovendo apici)"
    echo "2) Stampa (TUTTE le 9 colonne, compresi seen_count e rarity, rimuovendo apici e con cpi=17, lpi=8)"
    echo "3) Nessuna azione"
    read -p "Scegli un'opzione (1/2/3): " choice

    if [[ "$choice" == "1" || "$choice" == "2" ]]; then

        # 4. Creiamo un secondo file temporaneo (tmpfile2) in cui rimuoviamo gli apici
        #    dai campi 6 e 7 (first_seen, last_seen). E, a seconda del caso, taglieremo le colonne.
        local tmpfile2
        tmpfile2="$(mktemp)"

        # Usiamo AWK per togliere eventuali apici da colonna 6 e 7
        # Poi, a seconda se file o stampa, prendiamo 7 oppure 9 colonne.
        if [[ "$choice" == "1" ]]; then
            # Salvataggio su file => solo prime 7 colonne
            # (hex, flight, squawk, speed, altitude, first_seen, last_seen)
            awk -F',' 'NR==1 {
                print; 
                next 
            }
            {
                # Rimuoviamo apici in colonna 6 ($6) e 7 ($7)
                gsub(/^"/,"",$6); gsub(/"$/,"",$6)
                gsub(/^"/,"",$7); gsub(/"$/,"",$7)
                print
            }' OFS=',' "$tmpfile" \
             | cut -d',' -f1-7 \
             | column -s ',' -t > "$tmpfile2"

            read -p "Inserisci il percorso del file di destinazione: " outpath
            if [[ -n "$outpath" ]]; then
                cp "$tmpfile2" "$outpath"
                echo "Risultati salvati in '$outpath' (tabellare, senza seen_count né rarity)."
            else
                echo "Percorso non valido. Operazione annullata."
            fi

        elif [[ "$choice" == "2" ]]; then
            # Stampa => TUTTE e 9 colonne (incluse seen_count e rarity)
            awk -F',' 'NR==1 {
                print; 
                next 
            }
            {
                gsub(/^"/,"",$6); gsub(/"$/,"",$6)
                gsub(/^"/,"",$7); gsub(/"$/,"",$7)
                # Se volessi anche rimuovere apici dalle col. 8,9, potresti:
                # gsub(/^"/,"",$8); gsub(/"$/,"",$8)
                # gsub(/^"/,"",$9); gsub(/"$/,"",$9)
                print
            }' OFS=',' "$tmpfile" \
             | cut -d',' -f1-9 \
             | column -s ',' -t > "$tmpfile2"

            # Stampiamo con cpi=17, lpi=8
            lp -d "$PRINTER_NAME" -o cpi=17 -o lpi=8 "$tmpfile2"
            echo "Inviato alla stampante '$PRINTER_NAME' (con seen_count e rarity, cpi=17, lpi=8)."
        fi

        rm -f "$tmpfile2"
    else
        echo "Nessuna azione eseguita."
    fi

    # Rimuoviamo il file temporaneo principale
    rm -f "$tmpfile"
}

###############################################################################
## Funzione display_results_csv: legge CSV e lo mostra con TUTTE le colonne,
## compresi seen_count e rarity, colorando l'intera riga e togliendo apici
## su first_seen e last_seen (colonne 6 e 7) a video.
###############################################################################
display_results_csv() {
    local header_printed=false
    local IFS=$'\n'

    while read -r line; do
        if [ "$header_printed" = false ]; then
            # Prima riga = header
            IFS=',' read -r h_hex h_flight h_squawk h_speed h_alt h_fs h_ls h_sc h_ra <<< "$line"

            # Spostamenti intestazioni
            h_hex="  $h_hex"      # 2 spazi
            h_fs="       $h_fs"   # 7 spazi
            h_ls="        $h_ls"  # 8 spazi
            h_sc="    $h_sc"      # 4 spazi
            h_ra="    $h_ra"      # 4 spazi

            printf "%-12s %-10s %-8s %-8s %-8s %-19s %-19s %-9s %-9s\n" \
                "$h_hex" "$h_flight" "$h_squawk" "$h_speed" "$h_alt" "$h_fs" "$h_ls" "$h_sc" "$h_ra"

            header_printed=true
        else
            # Riga dati
            IFS=',' read -r hex flight squawk speed altitude first_seen last_seen seen_count rarity <<< "$line"

            # Togliamo eventuali doppi apici intorno a first_seen e last_seen
            first_seen=$(echo "$first_seen" | sed 's/^"//; s/"$//')
            last_seen=$(echo "$last_seen" | sed 's/^"//; s/"$//')

            # Spostiamo la colonna rarity di 6 spazi
            rarity="      $rarity"

            # Colori
            local color_start="\e[0m"
            local color_end="\e[0m"

            case "$rarity" in
                *Mythic)    color_start="\e[91m"  ;;  # Rosso
                *Legendary) color_start="\e[33m"  ;;  # Giallo/Arancio
                *Epic)      color_start="\e[35m"  ;;  # Viola
                *Rare)      color_start="\e[94m"  ;;  # Blu
                *Uncommon)  color_start="\e[92m"  ;;  # Verde
                *Common)    color_start="\e[97m"  ;;  # Bianco
            esac

            printf "${color_start}%-12s %-10s %-8s %-8s %-8s %-19s %-19s %-9s %-9s${color_end}\n" \
                "$hex" "$flight" "$squawk" "$speed" "$altitude" "$first_seen" "$last_seen" "$seen_count" "$rarity"
        fi
    done
}

###############################################################################
## Sezione: Ricerche e funzioni
## (resto invariato, con la logica altitudine e filtri ground/0)
###############################################################################

search_by_hex() {
    echo "Inserisci il codice HEX da cercare:"
    read hex_input
    [[ -z "$hex_input" ]] && { echo "Errore: non hai inserito un codice HEX."; return; }

    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE hex LIKE '${hex_input}%'
    ORDER BY last_seen ASC;
    "

    query_and_process "$sql"
}

search_by_callsign() {
    echo "Inserisci il callsign da cercare:"
    read callsign_input
    [[ -z "$callsign_input" ]] && { echo "Errore: non hai inserito un callsign."; return; }

    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE flight LIKE '${callsign_input}%'
    ORDER BY last_seen ASC;
    "

    query_and_process "$sql"
}

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
    echo "Inserisci la data (YYYY-MM-DD):"
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

    local order_clause
    case $order_choice in
        1) order_clause="ORDER BY hex ASC" ;;
        2) order_clause="ORDER BY flight ASC" ;;
        3) order_clause="ORDER BY last_seen ASC" ;;
        *) echo "Opzione non valida."; return ;;
    esac

    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE last_seen LIKE '${date_input}%'
    $order_clause;
    "

    query_and_process "$sql"
}

###############################################################################
## Classifiche con altitudine >0, escludendo '0' e 'ground'
###############################################################################

top_10_callsigns() {
    local sql="
    SELECT flight AS callsign, COUNT(*) AS count
    FROM adsb_contacts
    WHERE flight IS NOT NULL AND flight != ''
    GROUP BY flight
    ORDER BY count DESC
    LIMIT 10;
    "
    query_and_process "$sql"
}

highest_altitude() {
    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE altitude NOT IN (0, '0', 'ground')
      AND altitude > 0
    ORDER BY altitude DESC, last_seen ASC
    LIMIT 10;
    "
    query_and_process "$sql"
}

highest_speed() {
    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE hex NOT LIKE '~%'
    ORDER BY speed DESC
    LIMIT 10;
    "
    query_and_process "$sql"
}

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

###############################################################################
## Voli a terra, emergenza, militari
###############################################################################

ground_flights() {
    echo "=============================="
    echo "     Ordinamento Voli a Terra"
    echo "=============================="
    echo "1. Ordina per Data (dal più vecchio)"
    echo "2. Ordina per HEX (alfabetico)"
    echo "3. Ordina per Callsign (alfabetico)"
    echo "=============================="
    read -p "Scegli un'opzione: " order_choice

    local order_clause
    case $order_choice in
        1) order_clause="ORDER BY last_seen ASC" ;;
        2) order_clause="ORDER BY hex ASC" ;;
        3) order_clause="ORDER BY flight ASC" ;;
        *) echo "Opzione non valida. Riprova."; return ;;
    esac

    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE altitude IN (0, '0', 'ground')
      AND hex NOT LIKE '~%'
    $order_clause;
    "
    query_and_process "$sql"
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

    local order_clause
    case $order_choice in
        1) order_clause="ORDER BY last_seen ASC" ;;
        2) order_clause="ORDER BY hex ASC" ;;
        3) order_clause="ORDER BY flight ASC" ;;
        *) echo "Opzione non valida. Riprova."; return ;;
    esac

    local sql="
    WITH sorted AS (
        SELECT
            adsb_contacts.*,
            PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
        FROM adsb_contacts
    )
    SELECT
        hex,
        flight,
        squawk,
        speed,
        altitude,
        first_seen,
        last_seen,
        seen_count,
        CASE
            WHEN pr <= 0.001 THEN 'Mythic'
            WHEN pr <= 0.01  THEN 'Legendary'
            WHEN pr <= 0.05  THEN 'Epic'
            WHEN pr <= 0.15  THEN 'Rare'
            WHEN pr <= 0.30  THEN 'Uncommon'
            ELSE 'Common'
        END AS rarity
    FROM sorted
    WHERE squawk IN ('7500', '7600', '7700')
      AND hex NOT LIKE '~%'
    $order_clause;
    "
    query_and_process "$sql"
}

find_military_flights() {
    hex_query=$(awk '{print "hex LIKE \x27"$1"%\x27 OR "}' "$HEX_PREFIX_FILE" | sed '$ s/ OR $//')
    callsign_query=$(awk '{print "flight LIKE \x27"$1"%\x27 OR "}' "$CALLSIGN_PATTERN_FILE" | sed '$ s/ OR $//')
    local base_where="(($hex_query) OR ($callsign_query))"

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
            local sql="
            WITH sorted AS (
                SELECT
                    adsb_contacts.*,
                    PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
                FROM adsb_contacts
            )
            SELECT
                hex,
                flight,
                squawk,
                speed,
                altitude,
                first_seen,
                last_seen,
                seen_count,
                CASE
                    WHEN pr <= 0.001 THEN 'Mythic'
                    WHEN pr <= 0.01  THEN 'Legendary'
                    WHEN pr <= 0.05  THEN 'Epic'
                    WHEN pr <= 0.15  THEN 'Rare'
                    WHEN pr <= 0.30  THEN 'Uncommon'
                    ELSE 'Common'
                END AS rarity
            FROM sorted
            WHERE $base_where
            ORDER BY last_seen ASC;
            "
            query_and_process "$sql"
            ;;
        2)
            local sql="
            WITH sorted AS (
                SELECT
                    adsb_contacts.*,
                    PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
                FROM adsb_contacts
            )
            SELECT
                hex,
                flight,
                squawk,
                speed,
                altitude,
                first_seen,
                last_seen,
                seen_count,
                CASE
                    WHEN pr <= 0.001 THEN 'Mythic'
                    WHEN pr <= 0.01  THEN 'Legendary'
                    WHEN pr <= 0.05  THEN 'Epic'
                    WHEN pr <= 0.15  THEN 'Rare'
                    WHEN pr <= 0.30  THEN 'Uncommon'
                    ELSE 'Common'
                END AS rarity
            FROM sorted
            WHERE $base_where
            ORDER BY hex ASC;
            "
            query_and_process "$sql"
            ;;
        3)
            local sql="
            WITH sorted AS (
                SELECT
                    adsb_contacts.*,
                    PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
                FROM adsb_contacts
            )
            SELECT
                hex,
                flight,
                squawk,
                speed,
                altitude,
                first_seen,
                last_seen,
                seen_count,
                CASE
                    WHEN pr <= 0.001 THEN 'Mythic'
                    WHEN pr <= 0.01  THEN 'Legendary'
                    WHEN pr <= 0.05  THEN 'Epic'
                    WHEN pr <= 0.15  THEN 'Rare'
                    WHEN pr <= 0.30  THEN 'Uncommon'
                    ELSE 'Common'
                END AS rarity
            FROM sorted
            WHERE $base_where
            ORDER BY flight ASC;
            "
            query_and_process "$sql"
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

            local sub_clause
            case $sub_order_choice in
                1) sub_clause="ORDER BY hex ASC" ;;
                2) sub_clause="ORDER BY flight ASC" ;;
                3) sub_clause="ORDER BY last_seen ASC" ;;
                *) echo "Opzione non valida."; return ;;
            esac

            local sql="
            WITH sorted AS (
                SELECT
                    adsb_contacts.*,
                    PERCENT_RANK() OVER (ORDER BY seen_count ASC) AS pr
                FROM adsb_contacts
            )
            SELECT
                hex,
                flight,
                squawk,
                speed,
                altitude,
                first_seen,
                last_seen,
                seen_count,
                CASE
                    WHEN pr <= 0.001 THEN 'Mythic'
                    WHEN pr <= 0.01  THEN 'Legendary'
                    WHEN pr <= 0.05  THEN 'Epic'
                    WHEN pr <= 0.15  THEN 'Rare'
                    WHEN pr <= 0.30  THEN 'Uncommon'
                    ELSE 'Common'
                END AS rarity
            FROM sorted
            WHERE last_seen LIKE '${date_input}%'
              AND ($base_where)
            $sub_clause;
            "
            query_and_process "$sql"
            ;;
        *)
            echo "Opzione non valida."
            ;;
    esac
}

###############################################################################
## Sezione 7: Ricerca Online (API adsb.fi) - voce 3 => Registrazione
###############################################################################
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
                  .ac[] | "Hex: \(.hex)\nFlight: \(.flight)\nRegistration: \(.r)\nDescription: \(.desc)\nCategory: \(.category)\n"'
                ;;
            2)
                echo "Inserisci il callsign da cercare:"
                read callsign
                [[ -z "$callsign" ]] && { echo "Errore: non hai inserito un callsign."; continue; }
                curl -s "https://opendata.adsb.fi/api/v2/callsign/$callsign" | jq -r '
                  .ac[] | "Hex: \(.hex)\nFlight: \(.flight)\nRegistration: \(.r)\nDescription: \(.desc)\nCategory: \(.category)\n"'
                ;;
            3)
                echo "Inserisci la registrazione da cercare:"
                read reg
                [[ -z "$reg" ]] && { echo "Errore: non hai inserito una registrazione."; continue; }
                curl -s "https://opendata.adsb.fi/api/v2/registration/$reg" | jq -r '
                  .ac[] | "Hex: \(.hex)\nFlight: \(.flight)\nRegistration: \(.r)\nDescription: \(.desc)\nCategory: \(.category)\n"'
                ;;
            4) break ;;
            *) echo "Opzione non valida. Riprova." ;;
        esac
    done
}

###############################################################################
## Sezione: Statistiche e Info Hardware
###############################################################################
database_statistics() {
    echo "=============================="
    echo "       Statistiche Database"
    echo "=============================="

    local unique_hex
    unique_hex=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(DISTINCT hex) FROM adsb_contacts
        WHERE hex NOT LIKE '~%';
    ")

    local avg_altitude
    avg_altitude=$(sqlite3 "$DB_PATH" "
        SELECT AVG(altitude)
        FROM adsb_contacts
        WHERE altitude NOT IN (0, '0', 'ground')
          AND altitude > 0
          AND hex NOT LIKE '~%';
    ")
    avg_altitude=${avg_altitude:-0}
    avg_altitude=$(echo "$avg_altitude" | cut -d '.' -f 1)

    local avg_speed
    avg_speed=$(sqlite3 "$DB_PATH" "
        SELECT AVG(speed)
        FROM adsb_contacts
        WHERE speed > 0
          AND hex NOT LIKE '~%';
    ")
    avg_speed=${avg_speed:-0}
    avg_speed=$(echo "$avg_speed" | cut -d '.' -f 1)

    local db_size
    db_size=$(du -h "$DB_PATH" | awk '{print $1}')

    echo "Numero di HEX univoci salvati: $unique_hex"
    echo "Altitudine media (solo >0 e != ground): $avg_altitude piedi"
    echo "Velocità media (solo speed>0): $avg_speed nodi"
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

#########################
## Menu principale
#########################
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

