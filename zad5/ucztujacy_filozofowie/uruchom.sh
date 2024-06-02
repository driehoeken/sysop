#!/bin/bash

source lib_uczta_filozofow.sh

while getopts f:F:n:N:k:K:r:R: OPCJA
do
    case $OPCJA in
	f|F) declare -ri LICZBA_FILOZOFOW=$OPTARG;;
	n|N) declare -ri LICZBA_POSILKOW=$OPTARG;;
	k|K) declare -r CZAS_KONSUMPCJI=$OPTARG;;
	r|R) declare -r CZAS_ROZMYSLANIA=$OPTARG;;
	*) echo Nieznana opcja $OPTARG; exit 2;;
    esac
done

if test ${LICZBA_FILOZOFOW:-0} -lt 2
then
     readonly LICZBA_FILOZOFOW=5
fi

if test ${LICZBA_POSILKOW:-0} -lt 2
then
     readonly LICZBA_POSILKOW=7
fi

readonly PLIK_BLOKADY_BARIERY=$(mktemp Sync_XXXX) || (echo Nie udało się utworzyć pliku blokady bariery $(realpath $PLIK_BLOKADY_BARIERY); exit 3)
readonly PLIK_POTOKU_BARIERY=${PLIK_BLOKADY_BARIERY}_fifo
mkfifo ${PLIK_POTOKU_BARIERY} || (echo "Nie udało się utworzyć pliku potoku dla bariery $(realpath $PLIK_POTOKU_BARIERY)"; exit 4)
readonly KATALOG_STOLU=$(mktemp -d Stol_XXXX) || (echo Nie udało się utworzyć katalogu reprezentującego stół $(realpath $KATALOG_STOLU); exit 5)

for NUMER_WIDELCA in $(seq 1 ${LICZBA_FILOZOFOW})
do
    SCIEZKA_WIDELCA=${KATALOG_STOLU}/${NUMER_WIDELCA}
    touch $SCIEZKA_WIDELCA || (echo "Nie udało się utworzyć pliku reprezentującego widelec $(realpath ${SCIEZKA_WIDELCA})"; exit 6)
done

for NUMER_FILOZOFA in $(shuf -i1-$LICZBA_FILOZOFOW)
do
 PIERWSZY_WIDELEC=$NUMER_FILOZOFA	
 DRUGI_WIDELEC=$(((${NUMER_FILOZOFA}+1)%(${LICZBA_FILOZOFOW}+1)))
if [[ $DRUGI_WIDELEC -eq 0 ]]
	then
	    DRUGI_WIDELEC=$PIERWSZY_WIDELEC
	    PIERWSZY_WIDELEC=1
	fi
        (filozof ${NUMER_FILOZOFA} ${LICZBA_FILOZOFOW} ${LICZBA_POSILKOW} $(realpath ${PLIK_BLOKADY_BARIERY}) $(realpath ${PLIK_POTOKU_BARIERY}) ${KATALOG_STOLU}/${PIERWSZY_WIDELEC} ${KATALOG_STOLU}/${DRUGI_WIDELEC} ${CZAS_KONSUMPCJI} ${CZAS_ROZMYSLANIA})&
done

wait
rm -rf $KATALOG_STOLU $PLIK_BLOKADY_BARIERY $PLIK_POTOKU_BARIERY
exit 0