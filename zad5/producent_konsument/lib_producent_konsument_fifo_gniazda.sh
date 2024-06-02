#!/bin/bash

function komunikat() {
    echo "$(date +"%F %T.%N") $(hostname) PID:$BASHPID $0 Mag.:FIFO $1"
}

function start() {
    komunikat "---Kryterium zatrzymania: $1, pojemność magazynu: $2, czas realizacji ${3:-losowy ułamek} sek.---"
}

function stop() {
    komunikat "---Zakończenie w wyniku spełnienia kryterium zatrzymania dla $1 towarów---"
    exit 0
}

function produkcja_konsumpcja() {
    local readonly CZAS=${3:-0.0$RANDOM}
    sleep $CZAS
    komunikat "$1 $2 towar przez $CZAS sek."
}

function wyznacz_polke() {
    local readonly NUMER_POLKI=$((($1-1)%$2+1))
    komunikat "$1 Bieżąca półka: ${3}$NUMER_POLKI, sprawdzam stan magazynu..."
    return $NUMER_POLKI
}

function spotkanie_gniazdo() {
     local SOCKET=$2
     if ! nc -Ul $SOCKET >>/dev/null 2>&1 #poprawne uruchomienie nc powoduje utworzenie gniazda plikowego
     then
          echo -n '' | nc -U $SOCKET #zakończenie komunikacji
     fi
     komunikat "$1 Doszło do spotkania z wykorzystaniem gniazda: $SOCKET"
}

readonly LICZBA_WYMAGANYCH_PARAMETROW=9

case $0 in
'konsument.sh') OPIS_WYMAGANYCH_PARAMETROW='Wymagane określenie: nazw dwóch plików gniazd (odpowiednio dla sytuacji pustego i pełnego magazynu) oraz pliku blokady magazynu, prefiksu magazynu i półki, liczby produkowanych towarów i rozmiaru magazynu! Opcjonalnie można określić czas konsumpcji w sekundach.';;
'producent.sh') OPIS_WYMAGANYCH_PARAMETROW='Wymagane określenie: nazw dwóch plików gniazd (odpowiednio dla sytuacji pełnego i pustego magazynu) oraz pliku blokady magazynu, prefiksu magazynu i półki, liczby produkowanych towarów i rozmiaru magazynu! Opcjonalnie można określić czas produkcji w sekundach.';;
*) OPIS_WYMAGANYCH_PARAMETROW="Niepoprawna nazwa $0 pliku skryptu!";;
esac

if [ $# -lt $LICZBA_WYMAGANYCH_PARAMETROW ]; then
    komunikat "Użycie: $0 wymaga zdefiniownia przynajmniej $LICZBA_WYMAGANYCH_PARAMETROW parametrów! $OPIS_WYMAGANYCH_PARAMETROW" 
    exit 1
fi
