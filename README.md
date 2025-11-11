# 🚗 TuikeDevelopments - td_tracker

Zaawansowany system zleceń przestępczych z progresją reputacji dla ESX.

## 📦 Instalacja

1. Skopiuj folder `td_tracker` do `resources/`
2. Wykonaj `sql/install.sql` w swojej bazie danych
3. Dodaj do `server.cfg`: `ensure td_tracker`
4. Skonfiguruj pliki w folderze `config/`
5. Restart serwera

## 🎮 Jak grać

1. Otwórz tablet (lb_tablet)
2. Znajdź NPC zleceniodawcę w obszarze poszukiwań
3. Wybierz misję odpowiednią do swojej reputacji
4. Wykonaj zadanie i odbierz nagrodę

## 🛠️ Wymagania

- ESX Legacy
- oxmysql
- ox_lib
- ox_inventory
- ox_target
- lb_tablet
- cd_dispatch lub ps-dispatch

## 🎯 Komendy admina

- `/starttracker [etap]` - Uruchom misję
- `/tracker rep [ID] [ilość]` - Modyfikuj reputację

## 📞 Wsparcie

TuikeDevelopments © 2025
