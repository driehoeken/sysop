#!/bin/bash
# 2021.04.14

# uruchom.sh - skrypt uruchamiajacy czytelnikow i pisarzy

function komunikat() { # numer_czytelnika_lub_pisarza tekst_komunikatu. 
# Funkcja uzywa $BASHPID zamiast $$ aby poprawnie wyswietlic PID podprocesu, jest wiec zalezna od powloki Bash.
    echo $(date +"%F %T.%N") $(hostname)" PID:"$BASHPID ${FUNCNAME[${#FUNCNAME[@]}-2]}" nr:" $1 $2
}

function start() { # numer_czytelnika_lub_pisarza liczba_czytan_lub_pisan plik_tablicy plik_bariery [czas]
    komunikat $1 "+++START+++ Kryterium zatrzymania: $2, plik tablicy $3, plik bariery $4, czas realizacji ${5:-losowy ułamek} sek"
}

function stop() { # numer_czytelnika_lub_pisarza liczba_zrealizowanych_cykli
    komunikat $1 "---STOP--- Zakończenie w wyniku spełnienia kryterium zatrzymania dla $2 cykli"
    exit 0
}


function czytanie() { # numer_czytelnika plik_tablicy numer_cyklu [czas]
    local readonly CZAS=${4:-0.$RANDOM}
    komunikat $1 "     Rozpoczynam czytanie po raz $3 przez $CZAS sek."
    sleep $CZAS
    LINIA=$(tail -n 1 $2);
    komunikat $1 "          Odczytałem: $LINIA"
    komunikat $1 "     Zakończyłem czytanie po raz $3."
}

function pisanie() { # numer_pisarza plik_tablicy numer_cyklu [czas]
    local readonly CZAS=${4:-0.$RANDOM}
    komunikat $1 "     Rozpoczynam pisanie po raz $3 przez $CZAS sek."
    sleep $CZAS
    komunikat $1 "Oto jest mój wpis nr $3" >> $2
    komunikat $1 "     Zakończyłem pisanie po raz $3."
}

export komunikat start stop czytanie pisanie; # udostepnia funkcje dla podpowlok

function czytelnik() { # numer_czytelnika plik_tablicy plik_bariery liczba_odczytow [czas_czytania w sekundach]
    readonly NUMER_CZYTELNIKA=$1
    readonly PLIK_TABLICY_CZYTELNIK=$2
    readonly PLIK_BARIERY_PISARZ=$3 
    readonly ILE_ODCZYTOW=$4
    readonly ZWLOKA_ODCZYTU=$5

    # Zwiazanie deskryptora z plikiem blokady, bedacego jednoczesnie plikiem tablicy. Jest to niezbedne do pozniejszego wykonania polecenia flock, oczekujacego podania deskryptora pliku blokady.
    exec 13>$PLIK_TABLICY_CZYTELNIK;

    declare -i liczba_przeczytan=0;

    start $NUMER_CZYTELNIKA $ILE_ODCZYTOW $PLIK_TABLICY_CZYTELNIK $PLIK_BARIERY_PISARZ $ZWLOKA_ODCZYTU

    while [[ $liczba_przeczytan -lt $ILE_ODCZYTOW ]]; do
        if [[ $liczba_przeczytan -eq $ILE_ODCZYTOW-1 ]]; then
            komunikat $NUMER_CZYTELNIKA "*** PRZEJSCIE DO OSTATNIEGO ODCZYTU ***"
            komunikat $NUMER_CZYTELNIKA "     Spróbuję zyskać możliwość przejścia przez barierę (odczytać komunikat z pliku bariery).";
            # Odczytanie z potoku swiadczy o tym, ze nadzorca dotarl do petli wysylajacej te komunikaty, a zatem wszyscy pisarze musieli juz zakonczyc pisanie
            cat $PLIK_BARIERY_PISARZ >> /dev/null
            komunikat $NUMER_CZYTELNIKA "     Uzyskałem przejście przez barierę, przechodzę do ostatniego odczytu.";
        fi;
        komunikat $NUMER_CZYTELNIKA "Spróbuję zyskać dostęp do czytania (założyć blokadę współdzieloną na tablicy).";
        flock -s 13; # Zalozenie blokady wspoldzielonej na plik tablicy
            liczba_przeczytan=$liczba_przeczytan+1;
            czytanie $NUMER_CZYTELNIKA $PLIK_TABLICY_CZYTELNIK $liczba_przeczytan $ZWLOKA_ODCZYTU;
        flock -u 13; # zdjecie blokady
        komunikat $NUMER_CZYTELNIKA "Zdjąłem blokadę współdzieloną z tablicy.";

    done;

    stop $NUMER_CZYTELNIKA $liczba_przeczytan
}

function pisarz() { # numer_pisarza plik_tablicy plik_bariery liczba_zapisow [czas_pisania w sekundach]
    readonly NUMER_PISARZA=$1
    readonly PLIK_TABLICY_PISARZ=$2
    readonly PLIK_BARIERY_PISARZ=$3 
    readonly ILE_ZAPISOW=$4
    readonly ZWLOKA_ODCZYTU=$5

    # Zwiazanie deskryptora z plikiem blokady, bedacego jednoczesnie plikiem tablicy. Jest to niezbedne do pozniejszego wykonania polecenia flock, oczekujacego podania deskryptora pliku blokady.
    exec 13>$PLIK_TABLICY_PISARZ;

    declare -i liczba_zapisan=0;

    start $NUMER_PISARZA $ILE_ZAPISOW $PLIK_TABLICY_PISARZ $PLIK_BARIERY_PISARZ $ZWLOKA_ZAPISU

    while [[ $liczba_zapisan -lt $ILE_ZAPISOW ]]; do
        komunikat $NUMER_PISARZA "Spróbuję zyskać dostęp do pisania (założyć blokadę wyłączną na tablicy).";
        flock -x 13; # Zalozenie blokady wylacznej na plik tablicy
            liczba_zapisan=$liczba_zapisan+1;
            pisanie $NUMER_PISARZA $PLIK_TABLICY_PISARZ $liczba_zapisan $ZWLOKA_ZAPISU;
        flock -u 13; # zdjecie blokady
        komunikat $NUMER_PISARZA "Zdjąłem blokadę wyłączną z tablicy.";

    done;

    komunikat $NUMER_PISARZA "Informuję nadzorcę (uruchom.sh) o ostatnim zapisie";
    
    # ncat jest wykonane jako podproces, poniewaz nie zamierzamy zatrzymywac pisarzy - bariera dotyczy nadzorcy, pisarze moga zakonczyc dzialanie
    coproc ncat -U  $PLIK_BARIERY_PISARZ -c 'read'

    stop $NUMER_PISARZA $liczba_zapisan
}

# entry point
while getopts c:C:p:P:o:O:z:Z:t:T:b:B:r:R:w:W: OPCJA
do
    case $OPCJA in
        c|C) declare -ri LICZBA_CZYTELNIKOW=$OPTARG;;
        p|P) declare -ri LICZBA_PISARZY=$OPTARG;;
        o|O) declare -ri LICZBA_ODCZYTOW=$OPTARG;;
        z|Z) declare -ri LICZBA_ZAPISOW=$OPTARG;;
        t|T) readonly PLIK_TABLICY=$OPTARG;;
        b|B) readonly PLIK_BARIERY=$OPTARG;;
        r|R) readonly ZWLOKA_ODCZYTU=$OPTARG;;
        w|W) readonly ZWLOKA_ZAPISU=$OPTARG;;
        *) echo Nieznana opcja $OPTARG; exit 2;;
    esac
done
                                                        
if test ${LICZBA_CZYTELNIKOW:-0} -le 0; then readonly LICZBA_CZYTELNIKOW=5; fi;
if test ${LICZBA_PISARZY:-0} -le 0; then readonly LICZBA_PISARZY=3; fi;
if test ${LICZBA_ODCZYTOW:-0} -le 0; then readonly LICZBA_ODCZYTOW=5; fi;
if test ${LICZBA_ZAPISOW:-0} -le 0; then readonly LICZBA_ZAPISOW=3; fi;
readonly PLIK_TABLICY=${PLIK_TABLICY:-tablica.txt}
readonly PLIK_BARIERY=${PLIK_BARIERY:-/tmp/bariera}
readonly PLIK_BARIERY_PISARZY=${PLIK_BARIERY}"_pisarzy"
readonly PLIK_BARIERY_CZYTELNIKOW=${PLIK_BARIERY}"_czytelnika"

echo "${0}: liczba czytelników $LICZBA_CZYTELNIKOW, liczba pisarzy $LICZBA_PISARZY, liczba odczytów $LICZBA_ODCZYTOW, liczba zapisów $LICZBA_ZAPISOW, \
    plik tablicy $PLIK_TABLICY, prefiks plikow barier $PLIK_BARIERY, czas czytania ${ZWLOKA_ODCZYTU:-losowy}, czas pisania ${ZWLOKA_ZAPISU:-losowy}."

echo -n "" > $PLIK_TABLICY

# Dzialanie bariery polega na zatrzymywaniu sie pisarzy na probie odczytu z gniazda. Takze sam nadzorca (uruchom.sh) zatrzymuje sie na takiej probie.
# Zwolnienie bariery powinno wiec nastapic po osiagnieciu LICZBA_PISARZY+1 (stad zmienna OCZEKIWANA_LICZBA_POLACZEN) polaczen z gniazdem. Mozna to sprawdzic za pomoca netstat -x.
# W takiej sytuacji skrypt wykonywany jako opcja -c ncat kończy (fuser) wszystkie procesy nc zwiazane z tym gniazdem, co powoduje zwolnienie nadzorcy i w konsekwencji zwolnienie bariery czytelnikow
OCZEKIWANA_LICZBA_POLACZEN=$((LICZBA_PISARZY+1))
export OCZEKIWANA_LICZBA_POLACZEN # dla procesu potomnego coproc - ncat
export PLIK_BARIERY_PISARZY # dla procesu potomnego coproc - ncat
rm -f $PLIK_BARIERY_PISARZY
coproc podproces_bariery_pisarzy { ncat -v -m $OCZEKIWANA_LICZBA_POLACZEN -U -k -l $PLIK_BARIERY_PISARZY -c 'liczba_polaczen=$(netstat -x | grep "$PLIK_BARIERY_PISARZY" | wc -l) ; if [ $liczba_polaczen -eq $OCZEKIWANA_LICZBA_POLACZEN ]; then fuser -k $PLIK_BARIERY_PISARZY; else cat; fi ' ;} 2>&1

# Sprawdzenie czy udalo sie utworzyc proces ncat 
read odbior <&${podproces_bariery_pisarzy[0]}
read odbior <&${podproces_bariery_pisarzy[0]}

if [ "Ncat: Listening on $PLIK_BARIERY_PISARZY" != "$odbior" ]; then
    echo "Zakonczenie z powodu nieudanej proby otwarcia gniazda $PLIK_BARIERY_PISARZY"
    exit 1;
fi

# Utworzenie potokow dla czytelnikow
# Nie mozna wykorzystac jednego potoku, poniewaz jednokrotna operacja odczytu moze odczytac wszystkie komunikaty z kolejki
# Tego ograniczenia nie maja gniazda strumieniowe
for nr_czytelnika in $(seq 1 ${LICZBA_CZYTELNIKOW}); do
    plik_bariery_czytelnika=${PLIK_BARIERY_CZYTELNIKOW}"_"${nr_czytelnika}
    rm -f ${plik_bariery_czytelnika};
    mkfifo ${plik_bariery_czytelnika};
done

#uruchomienie czytelnikow
for nr_czytelnika in $(seq 1 ${LICZBA_CZYTELNIKOW}); do
    plik_bariery_czytelnika=${PLIK_BARIERY_CZYTELNIKOW}"_"${nr_czytelnika}
    (czytelnik ${nr_czytelnika} ${PLIK_TABLICY} ${plik_bariery_czytelnika} ${LICZBA_ODCZYTOW} ${ZWLOKA_ODCZYTU})&
done

#uruchomienie pisarzy
for nr_pisarza in $(seq 1 ${LICZBA_PISARZY}); do
    (pisarz ${nr_pisarza} ${PLIK_TABLICY} ${PLIK_BARIERY_PISARZY} ${LICZBA_ZAPISOW} ${ZWLOKA_ZAPISU})&
done

# Spotkanie przy barierze pisarzy - oczekiwanie na zakończenie wszystkich procesow nc zwiazanych z tym gniazdem
# w szczegolnosci z uruchomionym tu synchronicznie procesem nc
# w tym czasie czytelnicy moga sie juz zatrzymywac na swojej barierze
echo "********** Zatrzymanie na wspolnej barierze z pisarzami"
ncat -U $PLIK_BARIERY_PISARZY -c 'read'

# zakonczenie procesu nc swiadczy o zakonczeniu pisania przez wszystkich pisarzy
echo "********** Wszyscy pisarze zakonczyli pisanie"


# zwolnienie bariery spotkania czytelnikow
for nr_czytelnika in $(seq 1 ${LICZBA_CZYTELNIKOW}); do
    plik_bariery_czytelnika=${PLIK_BARIERY_CZYTELNIKOW}"_"${nr_czytelnika}
    echo "kontynuuj" >> ${plik_bariery_czytelnika}
done
# czytelnicy czytaja po raz ostatni


wait # w tym momencie moga byc jeszcze uruchomieni czytelnicy

echo "********** Wszyscy czytelnicy zakonczyli"

echo "${0}: ZAKONCZENIE."
