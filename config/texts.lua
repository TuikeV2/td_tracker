ConfigTexts = {}

ConfigTexts.Text3D = {
    npc = '[E] Porozmawiaj',
    delivery = 'Dostawa pojazdu',
    dismantle = '[E] Demontuj %s',
    loadPart = '[E] Załaduj część'
}

ConfigTexts.Dialogs = {
    npcGreeting = {
        title = 'Zleceniodawca',
        description = 'Reputacja: **%s** pkt\nDostępne: **Etap %s**',
        icon = 'fa-solid fa-user-secret',
        iconColor = '#FFD700'
    },
    policeWarning = {
        title = 'Zleceniodawca',
        description = 'Spadaj glino!',
        icon = 'fa-solid fa-shield',
        iconColor = '#FF0000'
    },
    insufficientRep = {
        title = 'Brak reputacji',
        description = 'Wymagane: **%s**\nTwoje: **%s**',
        icon = 'fa-solid fa-ban'
    }
}

ConfigTexts.Notifications = {
    missionStarted = {
        title = 'Zlecenie przyjęte',
        description = 'Tablice: **%s**\nSzukaj w zaznaczonym obszarze',
        type = 'success'
    },
    vehicleFound = {
        title = 'Właściwy pojazd',
        description = 'Otwórz go i uciekaj!',
        type = 'info'
    },
    vehicleWrong = {
        title = 'Zły pojazd',
        description = 'Tablice: **%s**',
        type = 'error'
    },
    lockpickSuccess = {
        title = 'Sukces',
        description = 'Pojazd otwarty',
        type = 'success'
    },
    lockpickFailed = {
        title = 'Porażka',
        description = 'Wytrych się złamał',
        type = 'error'
    },
    policeAlerted = {
        title = 'ALARM',
        description = 'Policja powiadomiona! Uciekaj!',
        type = 'error'
    },
    chaseEnded = {
        title = 'Otrząsnąłeś policję',
        description = 'Jedź do punktu zdania',
        type = 'success'
    },
    missionComplete = {
        title = 'Misja ukończona',
        description = '💰 $%s\n💵 $%s\n⭐ +%s rep',
        type = 'success'
    },
    missionFailed = {
        title = 'Misja nieudana',
        description = '%s\n❌ -%s rep',
        type = 'error'
    },
    cooldown = {
        title = 'Cooldown',
        description = 'Odczekaj: **%s**',
        type = 'warning'
    },
    npcAngry = {
        title = 'Ostrzeżenie',
        description = 'Próba %s/%s',
        type = 'warning'
    },
    partDismantled = {
        title = 'Część zdemontowana',
        description = 'Załaduj do busa',
        type = 'info'
    },
    allPartsLoaded = {
        title = 'Gotowe',
        description = 'Jedź sprzedać części',
        type = 'success'
    }
}

ConfigTexts.Context = {
    stage1 = {
        title = 'Etap 1: Kradzież',
        description = 'Ukradnij pojazd',
        icon = 'fa-solid fa-car'
    },
    stage2 = {
        title = 'Etap 2: Transport',
        description = 'Transportuj pojazd',
        icon = 'fa-solid fa-truck'
    },
    stage3 = {
        title = 'Etap 3: Rozbiórka',
        description = 'Rozłóż na części',
        icon = 'fa-solid fa-wrench'
    },
    close = {
        title = 'Zakończ',
        icon = 'fa-solid fa-xmark'
    }
}

ConfigTexts.Progress = {
    lockpicking = 'Otwieranie...',
    dismantling = 'Demontaż...',
    loading = 'Ładowanie...'
}