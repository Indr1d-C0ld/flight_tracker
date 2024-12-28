### 1. Panoramica ###

Strumento basato su shell script progettato per monitorare e gestire informazioni sui voli, provenienti da stazione ricevente tar1090 remota e raccolti su database locale. Utilizzando un database SQLite con i dati acquisiti, il programma consente di eseguire ricerche specifiche, filtrare dati per data, visualizzare classifiche, monitorare voli a terra e voli con squawk di emergenza, nonché isolare voli militari. Inoltre, offre la possibilità di stampare direttamente i risultati su una stampante di rete configurata tramite CUPS o salvare i dati in file per un'analisi successiva.

### 2. Requisiti di Sistema ###

Prima di procedere con l'installazione e la configurazione, assicurati che il tuo sistema soddisfi i seguenti requisiti:

    Sistema Operativo: Linux (es. Raspbian per Raspberry Pi)
    Dipendenze Software:
        bash (shell)
        sqlite3 (per la gestione del database)
        less (per la visualizzazione comoda dei risultati)
        curl e jq (per le ricerche API)
        lp (per la stampa tramite CUPS)
        lscpu, vcgencmd, df, free, uptime (per le informazioni hardware)
    Stampante di Rete (opzionale): Configurata con CUPS e qui denominata "Canon"

### 3. Preparazione del Sistema ###

3.1. Installazione delle Dipendenze

Assicurati che tutte le dipendenze siano installate. Puoi installarle utilizzando il gestore di pacchetti apt:

sudo apt update
sudo apt install bash sqlite3 less curl jq cups-client

3.2. Configurazione della Stampante con CUPS

    Installa CUPS:

sudo apt install cups

Aggiungi l'utente al gruppo lpadmin:

sudo usermod -aG lpadmin $(whoami)

Accedi all'interfaccia web di CUPS:

Apri un browser web e naviga su http://localhost:631/.

Aggiungi la Stampante, esempio: "Canon":

Segui le istruzioni nell'interfaccia web per aggiungere la tua stampante di rete e assicurati di assegnarle il nome, esempio: "Canon".

Verifica la Configurazione:

Assicurati che la stampante "Canon" sia disponibile e funzionante eseguendo un test di stampa:

    lp -d Canon /etc/os-release

3.3. Preparazione del Database SQLite

Assicurati che il database SQLite (data.db) sia presente nel percorso /home/pi/data.db. Se non esiste, crealo e popola la tabella flights con i dati appropriati.

sqlite3 /home/pi/data.db <<EOF
CREATE TABLE IF NOT EXISTS flights (
    id INTEGER PRIMARY KEY,
    hex TEXT,
    callsign TEXT,
    last_updated TEXT,
    altitude TEXT,
    speed INTEGER,
    squawk TEXT
    -- Aggiungi altri campi necessari
);
EOF

3.4. Permessi di Esecuzione

Rendi eseguibile lo script:

chmod +x flight_tracker.sh

### 4. Funzionalità ###

Il progetto offre le seguenti funzionalità principali:

    Ricerca Specifica:
        Cerca per HEX: Trova voli basati sul codice HEX.
        Cerca per Callsign: Trova voli basati sul callsign.

    Filtra per Data:
        Filtra i risultati in base a una data specifica e ordina per HEX, Callsign o Data.

    Voli a Terra:
        Visualizza voli attualmente a terra, ordinabili per Data, HEX o Callsign.

    Voli con Squawk d'Emergenza:
        Monitora voli che hanno segnalato squawk di emergenza (7500, 7600, 7700).

    Isola Voli Militari:
        Filtra e visualizza voli militari basati su prefissi HEX e pattern di Callsign.

    Classifiche:
        Top 10 Callsign: I callsign più frequenti.
        Top 10 Altitudine: I voli con la massima altitudine.
        Top 10 Velocità: I voli con la massima velocità.

    Ricerca Online (API adsb.fi):
        Esegue ricerche online utilizzando l'API di adsb.fi per HEX, Callsign o Registrazione.

    Statistiche Database:
        Mostra statistiche come il numero di HEX unici, altitudine media, velocità media e dimensione del database.

    Info Hardware:
        Visualizza informazioni hardware del sistema, inclusi CPU, temperatura, utilizzo disco e RAM, e uptime.

### 5. Guida all'Uso ###

5.1. Avvio del Programma

Per avviare il programma, esegui lo script nella tua shell:

./query.sh

5.2. Navigazione nel Menu Principale

Una volta avviato, vedrai il menu principale con diverse opzioni numerate. Inserisci il numero corrispondente all'opzione desiderata e premi INVIO.

=============================
      Flight Tracker
=============================
1. Ricerca Specifica
2. Filtra per Data
3. Voli a Terra
4. Voli con Squawk d'Emergenza
5. Isola Voli Militari
6. Classifiche
7. Ricerca Online (adsb.fi)
8. Statistiche Database
9. Info Hardware
0. Esci
=============================

Scegli un'opzione:

5.3. Dettaglio delle Opzioni

1. Ricerca Specifica

    Cerca per HEX:
        Inserisci il codice HEX desiderato.
        Visualizza i risultati con less per una comoda navigazione.
        Dopo la visualizzazione, scegli se stampare, salvare o non fare nulla con i risultati.

    Cerca per Callsign:
        Inserisci il callsign desiderato.
        Procedi come sopra.

2. Filtra per Data

    Inserisci una data nel formato YYYY-MM-DD.
    Scegli come ordinare i risultati:
        Ordina per HEX (alfabetico)
        Ordina per Callsign (alfabetico)
        Ordina per Data (cronologico)
    Visualizza i risultati e decidi se stampare o salvare.

3. Voli a Terra

    Visualizza i voli attualmente a terra.
    Scegli come ordinarli:
        Ordina per Data (dal più vecchio)
        Ordina per HEX (alfabetico)
        Ordina per Callsign (alfabetico)
    Visualizza i risultati e decidi se stampare o salvare.

4. Voli con Squawk d'Emergenza

    Visualizza i voli che hanno segnalato squawk di emergenza.
    Scegli come ordinarli:
        Ordina per Data (dal più vecchio)
        Ordina per HEX (alfabetico)
        Ordina per Callsign (alfabetico)
    Visualizza i risultati e decidi se stampare o salvare.

5. Isola Voli Militari

    Filtra e visualizza i voli militari basati su prefissi HEX e pattern di Callsign.
    Scegli come ordinarli:
        Ordina per Data (dal più vecchio)
        Ordina per HEX (alfabetico)
        Ordina per Callsign (alfabetico)
        Seleziona un giorno specifico (con ulteriori opzioni di ordinamento)
    Visualizza i risultati e decidi se stampare o salvare.

6. Classifiche

    Top 10 Callsign: Mostra i 10 callsign più frequenti.
    Top 10 Altitudine: Mostra i 10 voli con la massima altitudine.
    Top 10 Velocità: Mostra i 10 voli con la massima velocità.
    Scegli una classifica, visualizza i risultati e decidi se stampare o salvare.

7. Ricerca Online (API adsb.fi)

    Cerca per HEX, Callsign o Registrazione:
        Inserisci il parametro di ricerca desiderato.
        I risultati vengono ottenuti tramite l'API di adsb.fi.
        Visualizza i risultati e decidi se stampare o salvare.

8. Statistiche Database

    Visualizza statistiche sul database, inclusi:
        Numero di HEX unici
        Altitudine media
        Velocità media
        Dimensione del database

9. Info Hardware

    Mostra informazioni hardware del sistema, come:
        Frequenza CPU
        Tipo di Processore
        Temperatura CPU
        Spazio su disco occupato e disponibile
        RAM in uso e disponibile
        Uptime del sistema

0. Esci

    Chiude il programma.

5.4. Gestione dell'Output

Dopo ogni ricerca o filtro, i risultati vengono visualizzati utilizzando less. Una volta terminata la visualizzazione, ti verrà chiesto se desideri:

    Stampare l'Output:
        Viene inviato alla stampante di rete "Canon" configurata tramite CUPS.
        Assicurati che la stampante sia accesa e correttamente collegata alla rete.

    Salvare l'Output su File:
        Inserisci il nome del file desiderato (es. risultato.txt).
        Il file verrà salvato nella directory corrente o nel percorso specificato.

    Non Fare Nulla:
        L'output verrà semplicemente chiuso e il programma tornerà al menu precedente.

5.5. Esempi di Utilizzo
Esempio 1: Ricerca per HEX

    Avvia il programma:

    ./query.sh

    Seleziona l'opzione 1 per "Ricerca Specifica".

    Seleziona 1 per "Cerca per HEX".

    Inserisci il codice HEX desiderato, ad esempio ABC123.

    Visualizza i risultati con less.

    Dopo la visualizzazione, scegli di stampare, salvare o non fare nulla.

Esempio 2: Filtrare per Data e Salvare i Risultati

    Avvia il programma:

    ./query.sh

    Seleziona l'opzione 2 per "Filtra per Data".

    Inserisci la data, ad esempio 2024-04-25.

    Scegli l'opzione di ordinamento, ad esempio 3 per "Ordina per Data (cronologico)".

    Visualizza i risultati con less.

    Scegli di salvare l'output e inserisci il nome del file, ad esempio filtrato_2024-04-25.txt.

### 6. Risoluzione dei Problemi ###

6.1. Problemi di Stampa

    Errore: "Stampante non trovata o non disponibile."

    Soluzione:
        Verifica che la stampante "Canon" sia accesa e collegata alla rete.
        Controlla la configurazione di CUPS accedendo all'interfaccia web su http://localhost:631/.
        Assicurati di avere i permessi necessari per stampare.

6.2. Database Vuoto o Non Trovato

    Errore: "Nessun risultato trovato."

    Soluzione:
        Verifica che il database SQLite (/home/pi/data.db) esista e contenga dati nella tabella flights.
        Controlla i permessi di lettura sul file del database.

6.3. Dipendenze Mancanti

    Errore: Comandi come sqlite3, jq o lp non trovati.

    Soluzione:

        Installa le dipendenze mancanti utilizzando apt:

        sudo apt install sqlite3 jq cups-client

7. Contribuire

Se desideri contribuire al miglioramento del codice, sentiti libero di copiarlo e modificarlo, inviare segnalazioni di bug, richieste di funzionalità o contributi tramite il repository GitHub.
