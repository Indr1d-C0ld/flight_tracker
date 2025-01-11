flight_tracker

flight_tracker è un progetto di raccolta e consultazione dei contatti ADS-B, pensato per girare su 
un sistema come un Raspberry Pi (o altra distribuzione Linux) dotato di un ricevitore ADS-B e di un 
software come tar1090 / readsb / dump1090. Il cuore del sistema è un database SQLite che registra 
i dati dei voli, e uno script Bash che permette di interrogarlo, visualizzare statistiche, salvare 
o stampare i risultati.
Funzionalità principali

    Raccolta Dati tramite uno script Python (adsb_collector.py), che:
        Legge i dati JSON generati da tar1090 (o servizi simili).
        Li inserisce in un database SQLite, con un meccanismo di conteggio “solo alla prima 
occorrenza del giorno”.
        Memorizza campi come hex, flight, squawk, speed, altitude, first_seen, last_seen, 
seen_count.

    Consultazione tramite uno script Bash (flight_tracker.sh) che:
        Fornisce un menu interattivo con opzioni di ricerca (per HEX o Callsign), filtri per data, 
classifiche (top altitudine, top velocità, etc.) e funzioni dedicate (voli militari, emergenza 
squawk, voli a terra, statistiche di database).
        Mostra i dati a schermo in colonne allineate e colorate (stile “rarità” da giochi di 
ruolo).
        Salva su file o stampa i risultati (in tabellare pulito) con diverse opzioni di 
formattazione.

    Gestione Rarità:
        Il conteggio seen_count indica quante volte (in giorni diversi) è stato rilevato lo stesso 
hex.
        Una colonna calcolata al volo (tramite PERCENT_RANK()) assegna etichette “Common, Rare, 
Epic, … Myhtic” in base alla frequenza.

    Stampa con caratteri più fitti (cpi=17, lpi=8), per evitare che il testo vada a capo su pagine 
più strette.

    Esclusione di altitudini nulle o “ground” nelle classifiche di altitudine, per rendere le 
top 10 più pulite.

Struttura del progetto

Il progetto è composto principalmente da:

    adsb_collector.py
        Script Python che raccoglie i dati da tar1090/data/aircraft.json (o simile) e li 
inserisce/aggiorna in un database SQLite (adsb.db).
        Incrementa seen_count solo se un contatto viene rivisto in un giorno diverso da quello di 
last_count_date.
        Campi memorizzati: hex, flight, squawk, speed, altitude, first_seen, last_seen, seen_count, 
last_count_date.

    flight_tracker.sh
        Script Bash che fornisce un menu testuale per interrogare il database (adsb.db), mostrando 
i risultati colorati a video.
        Permette di filtrare i voli in base a callsign, altitudine, data, squawk d’emergenza, ecc.
        Consente la salvataggio su file e la stampa con formati diversi:
            Salva su file: prime 7 colonne, senza seen_count e rarity, in testo tabellare.
            Stampa: tutte le 9 colonne (inclusi seen_count e rarity), con caratteri più fitti 
(cpi=17, lpi=8).

    File di prefix/pattern militari (opzionali)
        hex_prefixes.txt
        callsign_patterns.txt
        Se presenti, vengono usati da flight_tracker.sh per isolare voli militari (in base a 
determinati prefissi esadecimali o callsign).

    Database:
        adsb.db (SQLite). Creata/aggiornata automaticamente da adsb_collector.py (se non esiste).

Prerequisiti

    Ambiente Linux (Raspberry Pi OS, Debian, Ubuntu, etc.).
    Python 3 e alcuni pacchetti di base (requests se vuoi scaricare JSON via HTTP).
    SQLite3 installato.
    tar1090 (o readsb, dump1090 o simili) in esecuzione, che fornisca dati ADS-B in JSON (di solito 
http://localhost/tar1090/data/aircraft.json).
    CUPS configurato, con una stampante di rete chiamata “Canon” (o cambia il nome in 
flight_tracker.sh).

Installazione e Configurazione

    Creare una cartella dedicata, ad esempio /home/pi/flight_tracker/.
    Copiare in tale cartella:
        adsb_collector.py
        flight_tracker.sh
        (Opzionale) hex_prefixes.txt e callsign_patterns.txt
    Rendere eseguibili gli script:

    chmod +x /home/pi/flight_tracker/adsb_collector.py
    chmod +x /home/pi/flight_tracker/flight_tracker.sh

    Verificare che in adsb_collector.py la variabile DB_PATH punti a 
/home/pi/flight_tracker/adsb.db e che TAR1090_URL sia corretto (es. 
http://localhost/tar1090/data/aircraft.json).
    Verificare in flight_tracker.sh:
        DB_PATH="/home/pi/flight_tracker/adsb.db"
        HEX_PREFIX_FILE="/home/pi/flight_tracker/hex_prefixes.txt"
        CALLSIGN_PATTERN_FILE="/home/pi/flight_tracker/callsign_patterns.txt"
        PRINTER_NAME="Canon" (o come si chiama la stampante CUPS).

Utilizzo
1. Raccolta dati

    Puoi eseguire manualmente /home/pi/flight_tracker/adsb_collector.py per raccogliere i dati dal 
flusso tar1090 e inserirli in adsb.db.
    Oppure, per un aggiornamento regolare, puoi aggiungere al cron (ad es. ogni 5 minuti):

    */5 * * * * /usr/bin/python3 /home/pi/flight_tracker/adsb_collector.py

    In questo modo seen_count e gli altri campi rimangono aggiornati.

2. Consultazione

    Esegui /home/pi/flight_tracker/flight_tracker.sh: apparirà un menu testuale con le principali 
opzioni:
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
    Dopo aver selezionato un estratto, vedrai i dati a schermo con colonne allineate e colorate 
(inclusi seen_count e rarity).
    Ti verrà chiesto se salvare i risultati su file o stamparli:
        Salva su file: include solo le prime 7 colonne (senza seen_count, rarity), in formato 
tabellare “pulito”.
        Stampa: include tutte le 9 colonne (compresi seen_count e rarity), con opzioni CUPS 
(cpi=17, lpi=8) per caratteri più piccoli.

3. Rarità e colorazione

    A video, ogni riga è associata a una rarità calcolata in tempo reale con PERCENT_RANK(), da 
Common (frequente) a Mythic (estremamente raro).
    Il contatore seen_count indica quanti giorni diversi abbiamo visto quell’hex.
    Il colore ANSI varia in base alla rarità (es. Blu per Rare, Viola per Epic, Rosso per Mythic, 
ecc.).

Estensioni e personalizzazioni

    Modificare i nomi delle colonne, i filtri (es. se vuoi escludere altitudini negative, ecc.).
    Cambiare la stampante (PRINTER_NAME) o le opzioni di lp (-o cpi=XX -o lpi=YY).
    Colore: puoi personalizzare la colonna rarity e la palette ANSI.
    Raccolta: se i dati tar1090 si trovano altrove o se preferisci un differente endpoint JSON, 
aggiorna TAR1090_URL in adsb_collector.py.

Conclusioni

flight_tracker fornisce un sistema completo di:

    Raccolta ADS-B e memorizzazione in SQLite con conteggio giornaliero.
    Interfaccia testuale in Bash per visualizzare, filtrare, salvare o stampare i risultati.
    Approccio di “rarità GdR” per identificare i voli meno frequenti.
    Compatibile con varie installazioni di tar1090 / readsb su Raspberry Pi o altre macchine Linux.

Con la guida e gli script riportati, è possibile iniziare subito a utilizzarlo, personalizzarlo, e 
condividerlo con altre persone interessate al monitoraggio ADS-B, alle statistiche sui voli e a una 
gestione “gamificata” (con rarità) dei contatti aerei.

Buon tracciamento!
