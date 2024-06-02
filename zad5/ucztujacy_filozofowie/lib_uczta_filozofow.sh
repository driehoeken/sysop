#!/bin/bash

function komunikat() {
    printf "%s %s PID:%6d FilozofID:%3d %s\n" "$(date +"%F %T.%N")" $(hostname) $BASHPID $1 "$2"
}

function start() { #numer_filozofa liczba_filozofów liczba_posiłków plik_blokady_bariery plik_potoku_bariery plik_pierwszego_widelca plik_drugiego_widelca czas_konsumpcji czas _rozmyślania
    komunikat $1 "___START___ Liczba filozofów: $2 Liczba posiłków: $3 Plik blokady bariery: $4 Plik potoku bariery: $5 Plik widelca pierwszego: $6 Plik drugiego widelca: $7 Czas konsumpcji: ${8:-losowy} Czas rozmyślania: ${9:-losowy}"
}

function stop() { #nr_filozofa liczba_zjedzonych_posilkow
    komunikat $1 "___STOP___ Liczba zjedzonych posiłków $2"
    exit 0
}

function podnies_widelec { #nr_filozofa nr_widelca deskryptor_widelca
    komunikat $1 "Próbuję podnieść widelec WID:$2 (Próba założenia blokady wyłącznej na pliku widelca)"
    flock -x $3
    komunikat $1 "Podniosłem widelec WID:$2 (Uzyskanie blokady wyłącznej na pliku widelca)"
}

function odloz_widelec { #nr_filozofa nr_widelca deskryptor_widelca
    komunikat $1 "Próbuję odłożyć widelec WID:$2 (Próba zdjęcia blokady wyłącznej z pliku widelca)"
    flock -u $3
    komunikat $1 "Odłożyłem widelec WID:$2 (Zdjęcie blokady wyłącznej z pliku widelca)"
}

function jedzenie { #nr_filozofa #liczba_zjedzonych_posilkow czas_konsumpcji
    local readonly CZAS=${3:-0.$RANDOM}
    komunikat $1 "Rozpocząłem jedzenie‚ czas jedzenia $CZAS sek., posiłek $2"
    sleep $CZAS
    komunikat $1 "Zakończyłem jedzenie posiłku $2"
}

function rozmyslaj { #nr_filozofa liczba_zjedzonych_posilkow czas_rozmyslania
    local readonly CZAS=${3:-0.$RANDOM}
    komunikat $1 "Rozpoczynam rozmyślanie, czas rozmyślania $CZAS sek. ostatni zjedzony posiłek $2"
    sleep $CZAS
    komunikat $1 "Zakończyłem rozmyślanie po posiłku $2"
}

function zaczekaj_na_innych() { #numer_filozofa liczba_filozofow deskryptor_pliku_blokady plik_blokady plik_potoku
flock -x -n $3
    if [[ $? -eq 0 ]]
    then
        komunikat $1 "Założyłem blokadę wyłączną na pliku $4"
	LICZNIK=$2
	while [[ $LICZNIK -gt 1 ]]
	do
	    LICZNIK=$(($LICZNIK-$(cat $5|wc -l)))
	done
    else
	komunikat $1 "Nie udało się założyć blokady wyłącznej na pliku blokady $4"
	echo >$5
	komunikat $1 "Zakładam blokadę wyłączną na pliku $4"
	flock -x $3
        komunikat $1 "Założyłem blokadę wyłączną na pliku $4"
    fi
    flock -u $3
    komunikat $1 "Zdjąłem blokadę wyłączną z pliku $4"
    
}

function filozof { #numer_filozofa liczba_filozofów liczba_posiłków plik_blokady_bariery plik_potoku_bariery plik_pierwszego_widelca plik_drugiego_widelca czas_konsumpcji czas _rozmyślania

    start $1 $2 $3 $4 $5 $6 $7 $8 $9

    DESKRYPTOR_BLOKADY=$((150+$1%100))
    DESKRYPTOR_WIDELEC_1=111
    DESKRYPTOR_WIDELEC_2=121
    eval "exec ${DESKRYPTOR_BLOKADY}>${4}"
    eval "exec ${DESKRYPTOR_WIDELEC_1}>${6}"
    eval "exec ${DESKRYPTOR_WIDELEC_2}>${7}"

    declare -i LICZBA_ZJEDZONYCH_POSILKOW=0

    while [[ $LICZBA_ZJEDZONYCH_POSILKOW -lt $3 ]]
    do
	podnies_widelec $1 $6 $DESKRYPTOR_WIDELEC_1
	podnies_widelec $1 $7 $DESKRYPTOR_WIDELEC_2

	LICZBA_ZJEDZONYCH_POSILKOW=$(($LICZBA_ZJEDZONYCH_POSILKOW+1))
	jedzenie $1 $LICZBA_ZJEDZONYCH_POSILKOW $8

	odloz_widelec $1 $7 $DESKRYPTOR_WIDELEC_2
	odloz_widelec $1 $6 $DESKRYPTOR_WIDELEC_1

	rozmyslaj $1 $LICZBA_ZJEDZONYCH_POSILKOW $9

	if [[ $LICZBA_ZJEDZONYCH_POSILKOW -eq $((${3}-${3}/2)) ]]
	then
	    komunikat $1 "___PAUZA___ Dotarłem do połowy uczty, liczba dotychczas zjedzonych posiłków $LICZBA_ZJEDZONYCH_POSILKOW"
	    zaczekaj_na_innych $1 $2 $DESKRYPTOR_BLOKADY $4 $5
	    komunikat $1 "Wszyscy filozofowie dotarli do połowy uczty, kontynuuję..."
	fi
    done

    stop $1 $LICZBA_ZJEDZONYCH_POSILKOW
}