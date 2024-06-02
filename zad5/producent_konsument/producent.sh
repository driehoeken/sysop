#!/bin/bash
source lib_producent_konsument_fifo_gniazda.sh

function produkcja_towaru() {
    produkcja_konsumpcja $1 'Wyprodukowałem' $2
}

function odloz_towar_na_polke() {
    touch $2 && komunikat "$1 Odłożyłem towar na półkę: $2"
}

readonly MY_SYNC=$1
readonly OTHER_SYNC=$2
readonly MY_FLAG=$3
readonly OTHER_FLAG=$4
readonly BLOKADA_MAGAZYNU=$5
readonly PREFIX_MAGAZYNU=$6
readonly PREFIX_POLKI=$7
readonly LICZBA_TOWAROW=$8
readonly ROZMIAR_MAGAZYNU=$9
readonly CZAS_PRODUKCJI=${10} #parametr opcjonalny

exec 7>$BLOKADA_MAGAZYNU
start $LICZBA_TOWAROW $ROZMIAR_MAGAZYNU $CZAS_PRODUKCJI

for ITERACJA in $(seq $LICZBA_TOWAROW)
do
    produkcja_towaru $ITERACJA $CZAS_PRODUKCJI

    flock -x 7
    wyznacz_polke $ITERACJA $ROZMIAR_MAGAZYNU
    if test -f ${POLKA=$PREFIX_MAGAZYNU/$PREFIX_POLKI$?}; then
        komunikat "$ITERACJA Magazyn pełny, na wszystkich $ROZMIAR_MAGAZYNU półkach jest towar"
        touch $MY_FLAG
        flock -u 7
        spotkanie_gniazdo $ITERACJA $MY_SYNC
        flock -x 7
    fi
    odloz_towar_na_polke $ITERACJA $POLKA
    if [ -f $OTHER_FLAG ]; then
       spotkanie_gniazdo $ITERACJA $OTHER_SYNC && rm $OTHER_FLAG $OTHER_SYNC
    fi
    flock -u 7
done

stop $LICZBA_TOWAROW
