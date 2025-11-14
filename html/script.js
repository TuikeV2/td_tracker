// ============================================
// TD TRACKER - ADMIN PANEL NUI
// ============================================

let currentTab = 'stats';
let playersList = [];
let locationsList = [];

// ============================================
// INITIALIZATION
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    initializeEventListeners();
    console.log('[TD Tracker Admin] NUI Loaded');
});

// ============================================
// NUI CALLBACKS
// ============================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch(data.action) {
        case 'openPanel':
            openPanel();
            break;
        case 'closePanel':
            closePanel();
            break;
        case 'updateStats':
            updateStats(data.stats);
            break;
        case 'updatePlayers':
            updatePlayersList(data.players);
            break;
        case 'updateLocations':
            updateLocationsList(data.locations, data.locationType);
            break;
        case 'notification':
            showNotification(data.message, data.type);
            break;
    }
});

// ============================================
// EVENT LISTENERS
// ============================================

function initializeEventListeners() {
    // Close panel
    document.getElementById('close-panel').addEventListener('click', closePanel);

    // ESC key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closePanel();
        }
    });

    // Tab navigation
    document.querySelectorAll('.nav-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            switchTab(tab.dataset.tab);
        });
    });

    // Player search
    document.getElementById('player-search').addEventListener('input', (e) => {
        filterPlayers(e.target.value);
    });

    // Command buttons
    document.querySelectorAll('.cmd-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            executeCommand(btn.dataset.command);
        });
    });

    // Mission save buttons
    document.querySelectorAll('.btn-save').forEach(btn => {
        btn.addEventListener('click', () => {
            saveMissionConfig(btn.dataset.stage);
        });
    });

    // Location type selector
    document.getElementById('location-type').addEventListener('change', (e) => {
        loadLocations(e.target.value);
    });

    // Add location button
    document.getElementById('add-location-btn').addEventListener('click', () => {
        addLocation();
    });
}

// ============================================
// PANEL CONTROLS
// ============================================

function openPanel() {
    const panel = document.getElementById('admin-panel');
    panel.classList.remove('hidden');

    // Request initial data
    fetch('https://td_tracker/requestData', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tab: currentTab })
    });
}

function closePanel() {
    const panel = document.getElementById('admin-panel');
    panel.classList.add('hidden');

    fetch('https://td_tracker/closePanel', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function switchTab(tabName) {
    currentTab = tabName;

    // Update nav tabs
    document.querySelectorAll('.nav-tab').forEach(tab => {
        tab.classList.toggle('active', tab.dataset.tab === tabName);
    });

    // Update content tabs
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${tabName}-tab`);
    });

    // Request data for this tab
    fetch('https://td_tracker/requestData', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tab: tabName })
    });
}

// ============================================
// STATS TAB
// ============================================

function updateStats(stats) {
    document.getElementById('active-players').textContent = stats.activePlayers || 0;
    document.getElementById('active-missions').textContent = stats.activeMissions || 0;
    document.getElementById('completed-today').textContent = stats.completedToday || 0;
    document.getElementById('failed-today').textContent = stats.failedToday || 0;
}

function updatePlayersList(players) {
    playersList = players;
    renderPlayersList(players);
}

function renderPlayersList(players) {
    const tbody = document.getElementById('players-tbody');
    tbody.innerHTML = '';

    players.forEach(player => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${player.id}</td>
            <td>${player.name}</td>
            <td>${player.reputation}</td>
            <td>${player.completed}</td>
            <td>${player.failed}</td>
            <td><span class="status-badge ${player.active ? 'active' : 'inactive'}">${player.active ? 'Aktywny' : 'Nieaktywny'}</span></td>
            <td>
                <button class="action-btn" onclick="viewPlayer(${player.id})">Podgląd</button>
                <button class="action-btn" onclick="teleportToPlayer(${player.id})">TP</button>
                <button class="action-btn success" onclick="startMissionForPlayer(${player.id})">Start Misji</button>
                <button class="action-btn danger" onclick="resetPlayer(${player.id})">Reset</button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

function filterPlayers(query) {
    const filtered = playersList.filter(p =>
        p.name.toLowerCase().includes(query.toLowerCase()) ||
        p.id.toString().includes(query)
    );
    renderPlayersList(filtered);
}

function viewPlayer(playerId) {
    fetch('https://td_tracker/viewPlayer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId })
    });
}

function teleportToPlayer(playerId) {
    fetch('https://td_tracker/teleportToPlayer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId })
    });
}

function resetPlayer(playerId) {
    if (!confirm('Czy na pewno chcesz zresetować tego gracza?')) return;

    fetch('https://td_tracker/resetPlayer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId })
    });
}

let selectedPlayerId = null;

function startMissionForPlayer(playerId) {
    selectedPlayerId = playerId;
    document.getElementById('start-mission-modal').classList.remove('hidden');
}

function closeStartMissionModal() {
    document.getElementById('start-mission-modal').classList.add('hidden');
    selectedPlayerId = null;
}

function confirmStartMission(stage) {
    if (!selectedPlayerId) return;

    fetch('https://td_tracker/executeCommand', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            command: 'startMission',
            playerId: parseInt(selectedPlayerId),
            value: parseInt(stage)
        })
    });

    closeStartMissionModal();
    showNotification(`Wystartowano misję Stage ${stage}`, 'success');
}

// ============================================
// COMMANDS TAB
// ============================================

function executeCommand(command) {
    let data = { command };

    // Gather required data based on command
    switch(command) {
        case 'setRep':
        case 'addRep':
        case 'removeRep':
            data.playerId = parseInt(document.getElementById('cmd-player-id').value);
            data.value = parseInt(document.getElementById('cmd-reputation').value);
            if (isNaN(data.playerId) || isNaN(data.value)) {
                showNotification('Wprowadź poprawne wartości!', 'error');
                return;
            }
            break;
        case 'resetRep':
            data.playerId = parseInt(document.getElementById('cmd-player-id').value);
            if (isNaN(data.playerId)) {
                showNotification('Wprowadź ID gracza!', 'error');
                return;
            }
            if (!confirm('Czy na pewno chcesz zresetować reputację tego gracza?')) return;
            break;
        case 'cancelMission':
        case 'completeMission':
        case 'failMission':
            data.playerId = parseInt(document.getElementById('cmd-mission-player').value);
            if (isNaN(data.playerId)) {
                showNotification('Wprowadź ID gracza!', 'error');
                return;
            }
            break;
        case 'startMission':
            data.playerId = parseInt(document.getElementById('cmd-mission-player').value);
            data.value = parseInt(document.getElementById('cmd-mission-stage').value) || 1;
            if (isNaN(data.playerId)) {
                showNotification('Wprowadź ID gracza!', 'error');
                return;
            }
            break;
    }

    fetch('https://td_tracker/executeCommand', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });

    updateFooterStatus(`Wykonywanie: ${command}...`);
}

// ============================================
// MISSIONS TAB
// ============================================

function saveMissionConfig(stage) {
    const stageNum = parseInt(stage);

    const config = {
        stage: stageNum,
        enabled: document.querySelector(`input[type="checkbox"][data-stage="${stage}"]`).checked,
        minReputation: parseInt(document.querySelector(`input[data-stage="${stage}"][data-field="minReputation"]`).value),
        chanceToAorB: parseInt(document.querySelector(`input[data-stage="${stage}"][data-field="chanceToAorB"]`).value),
        timeLimit: parseInt(document.querySelector(`input[data-stage="${stage}"][data-field="timeLimit"]`).value)
    };

    fetch('https://td_tracker/saveMissionConfig', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
    });

    showNotification(`Zapisano konfigurację Etapu ${stage}`, 'success');
}

// ============================================
// LOCATIONS TAB
// ============================================

function loadLocations(locationType) {
    if (!locationType) return;

    fetch('https://td_tracker/loadLocations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ locationType })
    });

    updateFooterStatus(`Ładowanie lokacji: ${locationType}...`);
}

function updateLocationsList(locations, locationType) {
    locationsList = locations;
    const grid = document.getElementById('locations-grid');
    grid.innerHTML = '';

    if (!locations || locations.length === 0) {
        grid.innerHTML = '<p style="color: #a0a0c0; text-align: center;">Brak lokacji tego typu</p>';
        return;
    }

    locations.forEach((loc, index) => {
        const card = document.createElement('div');
        card.className = 'location-card';
        card.innerHTML = `
            <h4>📍 Lokacja #${index + 1}</h4>
            <div class="location-info">X: ${loc.x?.toFixed(2) || 0}</div>
            <div class="location-info">Y: ${loc.y?.toFixed(2) || 0}</div>
            <div class="location-info">Z: ${loc.z?.toFixed(2) || 0}</div>
            ${loc.w !== undefined ? `<div class="location-info">Heading: ${loc.w?.toFixed(2) || 0}°</div>` : ''}
            ${loc.model ? `<div class="location-info">Model: ${loc.model}</div>` : ''}
            <div class="location-actions">
                <button class="cmd-btn" onclick="teleportToLocation(${index})">📍 TP</button>
                <button class="cmd-btn" onclick="editLocation('${locationType}', ${index})">✏️ Edytuj</button>
                <button class="cmd-btn danger" onclick="deleteLocation('${locationType}', ${index})">🗑️</button>
            </div>
        `;
        grid.appendChild(card);
    });

    updateFooterStatus('Lokacje załadowane');
}

function teleportToLocation(index) {
    fetch('https://td_tracker/teleportToLocation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            index,
            locationType: document.getElementById('location-type').value
        })
    });
}

function editLocation(locationType, index) {
    fetch('https://td_tracker/editLocation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ locationType, index })
    });

    showFreecamInfo();
}

function deleteLocation(locationType, index) {
    if (!confirm('Czy na pewno chcesz usunąć tę lokację?')) return;

    fetch('https://td_tracker/deleteLocation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ locationType, index })
    });
}

function addLocation() {
    const locationType = document.getElementById('location-type').value;
    if (!locationType) {
        showNotification('Wybierz typ lokacji!', 'error');
        return;
    }

    fetch('https://td_tracker/addLocation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ locationType })
    });

    showFreecamInfo();
}

function showFreecamInfo() {
    const info = document.getElementById('freecam-info');
    info.classList.remove('hidden');

    setTimeout(() => {
        info.classList.add('hidden');
    }, 5000);
}

// ============================================
// UTILITIES
// ============================================

function showNotification(message, type = 'info') {
    // You can implement a toast notification system here
    console.log(`[${type.toUpperCase()}] ${message}`);
    updateFooterStatus(message);
}

function updateFooterStatus(status) {
    document.getElementById('footer-status').textContent = status;
}

// ============================================
// SETTINGS TAB
// ============================================

function loadSettings() {
    fetch('https://td_tracker/getSettings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

window.addEventListener('message', (event) => {
    if (event.data.action === 'updateSettings') {
        const settings = event.data.settings;

        // Populate settings fields
        for (const [key, value] of Object.entries(settings)) {
            const element = document.querySelector(`[data-key="${key}"]`);
            if (element) {
                if (element.type === 'checkbox') {
                    element.checked = value === true || value === 1 || value === '1';
                } else {
                    element.value = value;
                }
            }
        }
    }
});

function saveAllSettings() {
    const settings = {};
    const elements = document.querySelectorAll('[data-key]');

    elements.forEach(el => {
        const key = el.getAttribute('data-key');
        if (el.type === 'checkbox') {
            settings[key] = el.checked;
        } else if (el.type === 'number') {
            settings[key] = parseFloat(el.value);
        } else {
            settings[key] = el.value;
        }
    });

    fetch('https://td_tracker/saveSettings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ settings })
    });

    showNotification('Ustawienia zapisane do MySQL!', 'success');
}

// ============================================
// NPC QUEST GIVER TAB
// ============================================

let npcLocationsList = [];

function loadNPCLocations() {
    fetch('https://td_tracker/getNPCLocations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

window.addEventListener('message', (event) => {
    if (event.data.action === 'updateNPCLocations') {
        npcLocationsList = event.data.locations;
        renderNPCList();
    }
});

function renderNPCList() {
    const container = document.getElementById('npc-list');
    if (!container) return;

    container.innerHTML = '';

    if (!npcLocationsList || npcLocationsList.length === 0) {
        container.innerHTML = '<div style="text-align: center; padding: 40px; color: #aaa;">Brak NPC Quest Giver. Dodaj nowy używając przycisku wyżej.</div>';
        return;
    }

    npcLocationsList.forEach(npc => {
        const card = document.createElement('div');
        card.className = `npc-card ${npc.enabled ? 'active' : ''}`;
        card.innerHTML = `
            <div class="npc-header">
                <span class="npc-title">NPC #${npc.id}</span>
                <span class="npc-status ${npc.enabled ? 'active' : 'inactive'}">
                    ${npc.enabled ? 'Aktywny' : 'Nieaktywny'}
                </span>
            </div>
            <div class="npc-details">
                <div class="npc-detail-row">
                    <label>Model:</label>
                    <span>${npc.model}</span>
                </div>
                <div class="npc-detail-row">
                    <label>Pozycja:</label>
                    <span>X: ${npc.coords.x.toFixed(2)}, Y: ${npc.coords.y.toFixed(2)}, Z: ${npc.coords.z.toFixed(2)}</span>
                </div>
                <div class="npc-detail-row">
                    <label>Heading:</label>
                    <span>${npc.heading.toFixed(2)}°</span>
                </div>
                ${npc.animation ? `
                <div class="npc-detail-row">
                    <label>Animacja:</label>
                    <span>${npc.animation.dict} / ${npc.animation.name}</span>
                </div>
                ` : ''}
            </div>
            <div class="npc-actions-row">
                <button class="npc-btn" onclick="editNPCLocation(${npc.id})">📝 Edytuj</button>
                <button class="npc-btn" onclick="teleportToNPC(${npc.id})">📍 TP</button>
                <button class="npc-btn ${npc.enabled ? 'danger' : ''}" onclick="toggleNPC(${npc.id})">
                    ${npc.enabled ? '❌ Wyłącz' : '✅ Włącz'}
                </button>
                <button class="npc-btn danger" onclick="deleteNPC(${npc.id})">🗑️ Usuń</button>
            </div>
        `;
        container.appendChild(card);
    });
}

function addNewNPC() {
    fetch('https://td_tracker/addNewNPC', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    showNotification('Wejdź w tryb freecam aby ustawić pozycję NPC', 'info');
}

function editNPCLocation(npcId) {
    fetch('https://td_tracker/editNPCLocation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ npcId })
    });
}

function teleportToNPC(npcId) {
    const npc = npcLocationsList.find(n => n.id === npcId);
    if (!npc) return;

    fetch('https://td_tracker/teleportToCoords', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ coords: npc.coords })
    });
    showNotification('Teleportowano do NPC', 'success');
}

function toggleNPC(npcId) {
    fetch('https://td_tracker/toggleNPC', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ npcId })
    });
}

function deleteNPC(npcId) {
    if (!confirm('Czy na pewno chcesz usunąć tego NPC?')) return;

    fetch('https://td_tracker/deleteNPC', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ npcId })
    });
}

function spawnAllNPC() {
    fetch('https://td_tracker/executeCommand', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command: 'respawnAllNPC' })
    });
    showNotification('Zespawnowano wszystkie NPC dla wszystkich graczy', 'success');
}
