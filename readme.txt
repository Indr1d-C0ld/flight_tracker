### AGGIORNAMENTO 11.08.2025 ###

Integrazione dello script "Rare Aircraft Notifier":

Questo script (post_rare_flights.py) automatizza il filtraggio dal database ADS-B locale dei contatti più rari, in base alla loro frequenza di avvistamento, risalenti al giorno prima.
Si integra con Telegram per inviare notifiche automatiche ogni notte con i contatti più interessanti.

Funzionalità principali:

    - Selezione mirata: vengono notificati solo i velivoli con livello di rarità alto, ovvero con contatore seen compreso tra 3 e 1.
    - Invio su Telegram: messaggi automatici a un canale o chat
    - Automazione: pensato per essere eseguito in automatico via cron (di default ogni notte alle 00:05).
    - Configurazione semplice tramite file config.json (token e chat ID di Telegram, percorso DB, ecc.).
    - Utilizza i files di referenza già esistenti callsign_patterns.txt e hex_prefixes.txt, per restringere la ricerca

Requisiti:

    - Python 3.x

    - pip install requests beautifulsoup4 (oppure sudo apt install python3-bs4)

    
Esecuzione automatica:

Aggiungere al crontab:

5 0 * * * /usr/bin/python3 /percorso/rare_aircraft_notifier.py


### Presentazione ###

flight_tracker è un progetto di raccolta e consultazione di contatti ADS-B, pensato per girare su un 
sistema basato (anche se non esclusivamente) su Raspberry Pi, dotato localmente di (*** o in grado di 
raggiungere da remoto ***) un ricevitore ADS-B e di software come tar1090 // readsb // dump1090. Il 
cuore del sistema è un database SQLite che registra i dati dei voli, e uno script Bash che permette di 
interrogarlo, visualizzare statistiche, salvare o stampare i risultati.

Gli script riportati, rendono possibile iniziare subito a utilizzare, personalizzare e condividerlo con 
altre persone interessate al monitoraggio ADS-B, alle statistiche sui voli e a una gestione “gamificata” 
(con rarità) dei contatti aerei!

Buon tracciamento!

### Funzionalità principali ###

    Raccolta Dati tramite uno script Python (adsb_collector.py), che:
        - Legge i dati JSON generati da tar1090 (o servizi simili).
        - Li inserisce in un database SQLite, con un meccanismo di conteggio “solo alla prima occorrenza del 
            giorno”.
        - Memorizza campi come hex, flight, squawk, speed, altitude, first_seen, last_seen, seen_count.

    Consultazione tramite uno script Bash (flight_tracker.sh) che:
        - Fornisce un menu interattivo con opzioni di ricerca (per HEX o Callsign), filtri per data, 
            classifiche (top altitudine, top velocità, etc.) e funzioni dedicate (voli militari, squawk di 
            emergenza, voli a terra, statistiche di database).
        - Mostra i dati a schermo in colonne allineate e righe colorate in stile “rarità” da giochi di ruolo!
        - Salva su file o stampa i risultati (in tabellare pulito) con diverse opzioni di formattazione.

    Gestione Rarità:
        - Il conteggio seen_count indica quante volte (in giorni diversi) è stato rilevato lo stesso hex.
        - Una colonna calcolata al volo (tramite PERCENT_RANK()) assegna etichette “Common, Rare, Epic, … 
            Myhtic” in base alla frequenza di "avvistamento".

     Stampa con caratteri più fitti (cpi=17, lpi=8), per evitare che il testo vada a capo su pagine più 
        strette.

    Esclusione di altitudini nulle o “ground” nelle classifiche di altitudine, per rendere le top 10 più 
        pulite.

### Struttura del progetto ###

Il progetto è composto principalmente da:

    adsb_collector.py:

        Script Python che raccoglie i dati da tar1090/data/aircraft.json (o simile) e li inserisce/aggiorna 
            in un database SQLite (adsb.db).
        Incrementa seen_count solo se un contatto viene rivisto in un giorno diverso da quello di 
            last_count_date.
        Campi memorizzati: hex, flight, squawk, speed, altitude, first_seen, last_seen, seen_count, 
            last_count_date.

    flight_tracker.sh:

        Script Bash che fornisce un menu testuale per interrogare il database (adsb.db), mostrando i 
            risultati colorati a video.
        Permette di filtrare i voli in base a callsign, altitudine, data, squawk d’emergenza, ecc.
        Consente il salvataggio su file e la stampa con formati diversi:
            - Salva su file: prime 7 colonne, senza seen_count e rarity, in testo tabellare.
            - Stampa: tutte le 9 colonne (inclusi seen_count e rarity), con caratteri più fitti (cpi=17, 
                lpi=8).

    File di prefix/pattern militari (opzionali):

        hex_prefixes.txt
        callsign_patterns.txt

        Se presenti, vengono usati da flight_tracker.sh per isolare voli militari (in base a determinati 
            prefissi esadecimali o callsign).

    Database:
        adsb.db (SQLite). Creato/aggiornato automaticamente da adsb_collector.py (se non esiste).

### Prerequisiti ###

    - Ambiente Linux (Raspberry Pi OS, Debian, Ubuntu, etc.).
    - Python 3 e alcuni pacchetti di base (requests se vuoi scaricare JSON via HTTP).
    - SQLite3 installato.
    - tar1090 (o readsb, dump1090 o simili) in esecuzione o raggiungibile da remoto via rete, che fornisca 
        dati ADS-B in JSON (di solito http://localhost/tar1090/data/aircraft.json).
    - CUPS configurato - nello script la stampante di rete è chiamata “Canon” (cambia il nome in 
        flight_tracker.sh).

### Installazione e Configurazione ###

    - Creare una cartella dedicata, ad esempio /home/pi/flight_tracker/.
    
    - Copiare in tale cartella:
        adsb_collector.py
        flight_tracker.sh
        (Opzionale) hex_prefixes.txt e callsign_patterns.txt
    
    - Rendere eseguibili gli script:

        chmod +x /home/pi/flight_tracker/adsb_collector.py
        chmod +x /home/pi/flight_tracker/flight_tracker.sh

    - Verificare che in adsb_collector.py la variabile DB_PATH punti a /home/pi/flight_tracker/adsb.db e che 
        TAR1090_URL sia corretto (es. http://localhost/tar1090/data/aircraft.json).

    - Verificare in flight_tracker.sh:
        DB_PATH="/home/pi/flight_tracker/adsb.db"
        HEX_PREFIX_FILE="/home/pi/flight_tracker/hex_prefixes.txt"
        CALLSIGN_PATTERN_FILE="/home/pi/flight_tracker/callsign_patterns.txt"
        PRINTER_NAME="Canon" (o come si chiama la stampante CUPS).

### Utilizzo ###

1. Raccolta dati

    Puoi eseguire manualmente /home/pi/flight_tracker/adsb_collector.py per raccogliere i dati dal flusso 
        tar1090 e inserirli in adsb.db.
    
    Oppure, per un aggiornamento regolare, puoi aggiungere al cron (ad es. ogni 5 minuti):

        */5 * * * * /usr/bin/python3 /home/pi/flight_tracker/adsb_collector.py

    In questo modo seen_count e gli altri campi rimangono aggiornati.

2. Consultazione

    Esegui /home/pi/flight_tracker/flight_tracker.sh: apparirà un menu testuale con le principali opzioni:

        Ricerca specifica (HEX/Callsign).
        Filtra per Data.
        Voli a Terra (altitudine=0/“ground”).
        Voli con Squawk d’Emergenza (7500, 7600, 7700).
        Isola Voli Militari (in base ai file prefix/pattern).
        Classifiche (Top 10 callsign, altitudine, velocità).
        Ricerca Online via API adsb.fi.
        Statistiche Database.
        Info Hardware (sistema).
        Esci.

    Dopo aver selezionato un estratto, vedrai i dati a schermo con colonne allineate e colorate (inclusi 
seen_count e rarity).

    Ti verrà chiesto se salvare i risultati su file o stamparli:
        - Salva su file: include solo le prime 7 colonne (senza seen_count, rarity), in formato tabellare 
            “pulito”.
        - Stampa: include tutte le 9 colonne (compresi seen_count e rarity), con opzioni CUPS (cpi=17, lpi=8) 
            per caratteri più piccoli.

3. Rarità e colorazione

    - A video, ogni riga è associata a una rarità calcolata in tempo reale con PERCENT_RANK(), da Common 
(frequente) a Mythic (estremamente raro).
    - Il contatore seen_count indica quanti giorni diversi abbiamo visto quell’hex.
    - Il colore ANSI varia in base alla rarità (es. Blu per Rare, Viola per Epic, Rosso per Mythic, ecc.).

### Estensioni e personalizzazioni ###

    - Modificare i nomi delle colonne, i filtri (es. se vuoi escludere altitudini negative, ecc.).
    - Cambiare la stampante (PRINTER_NAME) o le opzioni di lp (-o cpi=XX -o lpi=YY).
    - Colore: puoi personalizzare la colonna rarity e la palette ANSI.
    - Raccolta: se i dati tar1090 si trovano altrove o se preferisci un differente endpoint JSON, aggiorna 
        TAR1090_URL in adsb_collector.py.

### Conclusioni ###

flight_tracker fornisce un sistema completo di:

    - Raccolta ADS-B e memorizzazione in SQLite con conteggio giornaliero.
    - Interfaccia testuale in Bash per visualizzare, filtrare, salvare o stampare i risultati.
    - Approccio di “rarità GdR” per identificare i voli meno frequenti.
    - Compatibile con varie installazioni di tar1090 / readsb su Raspberry Pi o altre macchine Linux.

-----------------------------------------------------------------------------------------------------------

### ENGLISH: ###

### UPDATE 11.08.2025 ###

Integration of the "Rare Aircraft Notifier" script:

This script (post_rare_flights.py) automates filtering the rarest contacts from the local ADS-B database, based on their sighting frequency, dating back to the previous day.
It integrates with Telegram to send automatic notifications every night with the most interesting contacts.

Main features:

- Targeted selection: Only aircraft with a high rarity level, i.e., a seen count between 3 and 1, are notified.
- Send to Telegram: Automatic messages to a channel or chat.
- Automation: Designed to run automatically via cron (by default, every night at 00:05).
- Simple configuration via config.json file (Telegram token and chat ID, DB path, etc.).
- Use the existing reference files, callsign_patterns.txt and hex_prefixes.txt, to narrow your search.

Requirements:

- Python 3.x

- pip install requests beautifulsoup4 (or sudo apt install python3-bs4)

Automatic execution:

Add to crontab:

5 0 * * * /usr/bin/python3 /path/rare_aircraft_notifier.py


### Presentation ###

flight_tracker is a project for collecting and consulting ADS-B contacts, designed to run on a system based
(though not exclusively) on Raspberry Pi, equipped locally with (or capable of remotely accessing) an ADS-B 
receiver and software such as tar1090 // readsb // dump1090. The core of the system is an SQLite database 
that records flight data, and a Bash script that allows querying it, viewing statistics, saving, or printing 
the results.

The provided scripts make it possible to start using, customizing, and sharing it immediately with others 
interested in ADS-B monitoring, flight statistics, and a “gamified” (with rarity) management of air contacts!

Happy tracking!

### Main Features ###

    Data Collection through a Python script (adsb_collector.py), which:
        - Reads JSON data generated by tar1090 (or similar services).
        - Inserts them into an SQLite database, with a counting mechanism “only on the first occurrence of 
            the day.”
        - Stores fields such as hex, flight, squawk, speed, altitude, first_seen, last_seen, seen_count.

    Consultation through a Bash script (flight_tracker.sh) that:
        - Provides an interactive menu with search options (by HEX or Callsign), date filters, rankings (top 
            altitude, top speed, etc.), and dedicated functions (military flights, emergency squawks, ground 
            flights, database statistics).
        - Displays data on the screen in aligned columns and colored rows in a “rarity” style reminiscent of 
            role-playing games!
        - Saves results to a file or prints them (in clean tabular format) with various formatting options.

    Rarity Management:
        - The seen_count indicates how many times (on different days) the same hex has been detected.
        - A dynamically calculated column (using PERCENT_RANK()) assigns labels like “Common, Rare, Epic, 
            … Mythic” based on the frequency of sightings.

    Printing with Higher Density Characters (cpi=17, lpi=8) to prevent text from wrapping on narrower pages.

    Exclusion of Zero or “Ground” Altitudes in altitude rankings to make the top 10 cleaner.

### Project Structure ###

The project mainly consists of:

    adsb_collector.py:

        A Python script that collects data from tar1090/data/aircraft.json (or similar) and inserts/updates it 
            in an SQLite database (adsb.db).
        Increments seen_count only if a contact is revisited on a different day from last_count_date.
        Stored fields: hex, flight, squawk, speed, altitude, first_seen, last_seen, seen_count, last_count_date.

    flight_tracker.sh:

        A Bash script that provides a text-based menu to query the database (adsb.db), displaying color-coded 
            results on screen.
        Allows filtering flights based on callsign, altitude, date, emergency squawk, etc.
        Enables saving to a file and printing with different formats:
            - Save to file: first 7 columns, without seen_count and rarity, in clean tabular text.
            - Print: all 9 columns (including seen_count and rarity), with denser characters (cpi=17, lpi=8).

    Optional Military Prefix/Pattern Files:

        hex_prefixes.txt
        callsign_patterns.txt

        If present, they are used by flight_tracker.sh to isolate military flights (based on specific 
            hexadecimal prefixes or callsigns).

    Database:

        adsb.db (SQLite). Automatically created/updated by adsb_collector.py (if it does not exist).

### Prerequisites ###

    - Linux environment (Raspberry Pi OS, Debian, Ubuntu, etc.).
    - Python 3 and some basic packages (requests if you want to download JSON via HTTP).
    - SQLite3 installed.
    - tar1090 (or readsb, dump1090, or similar) running or accessible remotely via network, providing ADS-B data 
        in JSON (usually http://localhost/tar1090/data/aircraft.json).
    - CUPS configured – in the script, the network printer is named “Canon” (change the name in flight_tracker.sh).

### Installation and Configuration ###

    Create a Dedicated Folder, for example, /home/pi/flight_tracker/.

    Copy to this Folder:
        adsb_collector.py
        flight_tracker.sh
        (Optional) hex_prefixes.txt and callsign_patterns.txt

    Make the Scripts Executable:

chmod +x /home/pi/flight_tracker/adsb_collector.py
chmod +x /home/pi/flight_tracker/flight_tracker.sh

Verify in adsb_collector.py:

    Ensure the DB_PATH variable points to /home/pi/flight_tracker/adsb.db.
    Ensure TAR1090_URL is correct (e.g., http://localhost/tar1090/data/aircraft.json).

Verify in flight_tracker.sh:

    DB_PATH="/home/pi/flight_tracker/adsb.db"
    HEX_PREFIX_FILE="/home/pi/flight_tracker/hex_prefixes.txt"
    CALLSIGN_PATTERN_FILE="/home/pi/flight_tracker/callsign_patterns.txt"
    PRINTER_NAME="Canon" # or the name of your CUPS printer

### Usage ###

    Data Collection:

        You can manually execute /home/pi/flight_tracker/adsb_collector.py to collect data from the tar1090 
            stream and insert it into adsb.db.

        Alternatively, for regular updates, add to cron (e.g., every 5 minutes):

        */5 * * * * /usr/bin/python3 /home/pi/flight_tracker/adsb_collector.py

        This way, seen_count and other fields remain updated.

    Consultation:

        Run /home/pi/flight_tracker/flight_tracker.sh: a text-based menu will appear with the main options:

            Specific search (HEX/Callsign).
            Filter by Date.
            Ground Flights (altitude=0/"ground").
            Flights with Emergency Squawk (7500, 7600, 7700).
            Isolate Military Flights (based on prefix/pattern files).
            Rankings (Top 10 callsigns, altitude, speed).
            Online Search via adsb.fi API.
            Database Statistics.
            Hardware Info (system).
            Exit.

        After selecting an option, you will see the data on the screen with aligned and colored columns 
            (including seen_count and rarity).

        You will be prompted to save the results to a file or print them:
            Save to file: includes only the first 7 columns (without seen_count, rarity), in a “clean” tabular format.
            Print: includes all 9 columns (including seen_count and rarity), with CUPS options (cpi=17, lpi=8) 
                for smaller characters.

    Rarity and Coloring:
        On screen, each row is associated with a rarity calculated in real-time using PERCENT_RANK(), from Common 
            (frequent) to Mythic (extremely rare).
        The seen_count counter indicates how many different days that hex has been seen.
        The ANSI color varies based on rarity (e.g., Blue for Rare, Purple for Epic, Red for Mythic, etc.).

### Extensions and Customizations ###

    - Modify column names, filters (e.g., if you want to exclude negative altitudes, etc.).
    - Change the printer (PRINTER_NAME) or lp options (-o cpi=XX -o lpi=YY).
    - Color: You can customize the rarity column and the ANSI palette.
    - Collection: If tar1090 data is located elsewhere or if you prefer a different JSON endpoint, update TAR1090_URL in adsb_collector.py.

### Conclusions ###

flight_tracker provides a comprehensive system for:

    - Collecting ADS-B data and storing it in SQLite with daily counts.
    - A text-based Bash interface to view, filter, save, or print results.
    - A “GdR rarity” approach to identify less frequent flights.
    - Compatible with various tar1090/readsb installations on Raspberry Pi or other Linux machines.
