-- ============================================
-- TD TRACKER - MYSQL DATABASE STRUCTURE V2
-- Pełna integracja z MySQL
-- ============================================

-- Tabela konfiguracji etapów misji
CREATE TABLE IF NOT EXISTS `td_tracker_stages` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `stage` INT NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `min_reputation` INT NOT NULL DEFAULT 0,
    `chance_to_aorb` INT NOT NULL DEFAULT 50,
    `time_limit` INT NOT NULL DEFAULT 600000,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `stage` (`stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Wstaw domyślne wartości
INSERT INTO `td_tracker_stages` (`stage`, `name`, `enabled`, `min_reputation`, `chance_to_aorb`, `time_limit`) VALUES
(1, 'Kradzież', 1, 0, 20, 600000),
(2, 'Transport', 1, 500, 40, 900000),
(3, 'Rozbiórka', 1, 1000, 70, 1800000)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`),
    `enabled` = VALUES(`enabled`),
    `min_reputation` = VALUES(`min_reputation`),
    `chance_to_aorb` = VALUES(`chance_to_aorb`),
    `time_limit` = VALUES(`time_limit`);

-- Tabela lokacji NPC
CREATE TABLE IF NOT EXISTS `td_tracker_npc_locations` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `location_type` VARCHAR(50) NOT NULL COMMENT 'quest_giver, stage1_npc, stage2_npc, stage3_npc',
    `model` VARCHAR(50) NOT NULL,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0.0,
    `animation_dict` VARCHAR(100) DEFAULT NULL,
    `animation_name` VARCHAR(100) DEFAULT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `location_type` (`location_type`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela lokacji pojazdów
CREATE TABLE IF NOT EXISTS `td_tracker_vehicle_locations` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `stage` INT NOT NULL COMMENT '1, 2, 3',
    `location_type` VARCHAR(50) NOT NULL COMMENT 'spawn, delivery, hideout, bus_spawn, sell_point',
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0.0,
    `vehicle_model` VARCHAR(50) DEFAULT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `priority` INT NOT NULL DEFAULT 0 COMMENT 'Wyższa wartość = wyższy priorytet przy losowaniu',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `stage_type` (`stage`, `location_type`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela obszarów wyszukiwania (Stage 1)
CREATE TABLE IF NOT EXISTS `td_tracker_search_areas` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(100) NOT NULL,
    `center_x` FLOAT NOT NULL,
    `center_y` FLOAT NOT NULL,
    `center_z` FLOAT NOT NULL,
    `radius` FLOAT NOT NULL DEFAULT 200.0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela pojazdów do kradzieży (pule modeli)
CREATE TABLE IF NOT EXISTS `td_tracker_vehicle_pools` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `stage` INT NOT NULL,
    `tier` ENUM('A', 'B', 'C') NOT NULL DEFAULT 'C',
    `model` VARCHAR(50) NOT NULL,
    `spawn_chance` INT NOT NULL DEFAULT 100 COMMENT 'Szansa spawnu (1-100)',
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `stage_tier` (`stage`, `tier`, `enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Wstaw przykładowe pojazdy
INSERT INTO `td_tracker_vehicle_pools` (`stage`, `tier`, `model`, `spawn_chance`) VALUES
-- Stage 1 - Kradzież
(1, 'C', 'blista', 100),
(1, 'C', 'asea', 100),
(1, 'C', 'prairie', 100),
(1, 'B', 'fugitive', 80),
(1, 'B', 'buffalo', 80),
(1, 'B', 'dominator', 70),
(1, 'A', 'schwarzer', 50),
(1, 'A', 'sentinel', 50),
(1, 'A', 'carbonizzare', 30),
-- Stage 2 - Transport
(2, 'C', 'burrito', 100),
(2, 'C', 'rumpo', 100),
(2, 'B', 'bison', 80),
(2, 'B', 'youga', 80),
(2, 'A', 'speedo', 60),
-- Stage 3 - Rozbiórka
(3, 'C', 'emperor', 100),
(3, 'C', 'peyote', 100),
(3, 'B', 'sabregt', 80),
(3, 'B', 'buccaneer', 80),
(3, 'A', 'chino', 60),
(3, 'A', 'virgo', 60)
ON DUPLICATE KEY UPDATE
    `spawn_chance` = VALUES(`spawn_chance`);

-- Tabela nagród
CREATE TABLE IF NOT EXISTS `td_tracker_rewards` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `stage` INT NOT NULL,
    `tier` ENUM('A', 'B', 'C') NOT NULL DEFAULT 'C',
    `min_money` INT NOT NULL DEFAULT 0,
    `max_money` INT NOT NULL DEFAULT 0,
    `min_reputation` INT NOT NULL DEFAULT 0,
    `max_reputation` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `stage_tier` (`stage`, `tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Wstaw domyślne nagrody
INSERT INTO `td_tracker_rewards` (`stage`, `tier`, `min_money`, `max_money`, `min_reputation`, `max_reputation`) VALUES
-- Stage 1
(1, 'C', 5000, 8000, 10, 20),
(1, 'B', 8000, 12000, 20, 30),
(1, 'A', 12000, 18000, 30, 50),
-- Stage 2
(2, 'C', 10000, 15000, 20, 35),
(2, 'B', 15000, 22000, 35, 50),
(2, 'A', 22000, 30000, 50, 75),
-- Stage 3
(3, 'C', 15000, 20000, 30, 45),
(3, 'B', 20000, 28000, 45, 65),
(3, 'A', 28000, 40000, 65, 100)
ON DUPLICATE KEY UPDATE
    `min_money` = VALUES(`min_money`),
    `max_money` = VALUES(`max_money`),
    `min_reputation` = VALUES(`min_reputation`),
    `max_reputation` = VALUES(`max_reputation`);

-- Tabela kar za porażkę
CREATE TABLE IF NOT EXISTS `td_tracker_penalties` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `stage` INT NOT NULL,
    `reputation_loss` INT NOT NULL DEFAULT 20,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `stage` (`stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `td_tracker_penalties` (`stage`, `reputation_loss`) VALUES
(1, 20),
(2, 30),
(3, 50)
ON DUPLICATE KEY UPDATE
    `reputation_loss` = VALUES(`reputation_loss`);

-- Tabela konfiguracji ogólnej
CREATE TABLE IF NOT EXISTS `td_tracker_config` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `config_key` VARCHAR(100) NOT NULL,
    `config_value` TEXT NOT NULL,
    `config_type` ENUM('string', 'number', 'boolean', 'json') NOT NULL DEFAULT 'string',
    `description` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Wstaw domyślną konfigurację
INSERT INTO `td_tracker_config` (`config_key`, `config_value`, `config_type`, `description`) VALUES
('enable_anticheat', '0', 'boolean', 'Włącz system anti-cheat'),
('max_distance_from_vehicle', '150.0', 'number', 'Maksymalna odległość od pojazdu'),
('check_interval', '5000', 'number', 'Interval sprawdzania (ms)'),
('require_lockpick_item', '0', 'boolean', 'Wymagaj przedmiotu lockpick'),
('lockpick_break_chance', '15', 'number', 'Szansa na zepsucie lockpicka (%)'),
('alarm_duration', '15000', 'number', 'Czas trwania alarmu (ms)'),
('chase_time', '30000', 'number', 'Czas pościgu (ms)'),
('dismantle_time', '16000', 'number', 'Czas demontażu części (ms)'),
('require_dismantle_minigame', '0', 'boolean', 'Wymagaj minigry przy demontażu'),
('debug_mode', '1', 'boolean', 'Tryb debug'),
('npc_chase_enabled', '1', 'boolean', 'Włącz pościg NPC'),
('min_police_for_npc_disable', '5', 'number', 'Min. graczy policji aby wyłączyć NPC'),
('npc_initial_chasers', '10', 'number', 'Początkowa liczba radiowozów NPC'),
('npc_max_chasers', '30', 'number', 'Maksymalna liczba radiowozów NPC'),
('npc_drive_speed', '200.0', 'number', 'Prędkość radiowozów NPC'),
('npc_exit_distance', '200.0', 'number', 'Dystans wysiadania z pojazdu NPC'),
('npc_exit_delay', '1000', 'number', 'Opóźnienie wysiadania NPC (ms)')
ON DUPLICATE KEY UPDATE
    `config_value` = VALUES(`config_value`),
    `description` = VALUES(`description`);

-- Tabela aktywnych misji (cache)
CREATE TABLE IF NOT EXISTS `td_tracker_active_missions` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `stage` INT NOT NULL,
    `tier` ENUM('A', 'B', 'C') NOT NULL,
    `vehicle_model` VARCHAR(50),
    `vehicle_plate` VARCHAR(10),
    `start_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `data` JSON,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`),
    KEY `start_time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela reputacji graczy (z install.sql)
CREATE TABLE IF NOT EXISTS `td_tracker_reputation` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `reputation` INT NOT NULL DEFAULT 0,
    `completed_missions` INT NOT NULL DEFAULT 0,
    `failed_missions` INT NOT NULL DEFAULT 0,
    `last_mission` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela logów misji (z install.sql)
CREATE TABLE IF NOT EXISTS `td_tracker_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `stage` INT NOT NULL,
    `tier` ENUM('A', 'B', 'C') NOT NULL,
    `vehicle_model` VARCHAR(50),
    `vehicle_plate` VARCHAR(10),
    `success` TINYINT(1) NOT NULL DEFAULT 0,
    `money_earned` INT DEFAULT 0,
    `reputation_earned` INT DEFAULT 0,
    `time_taken` INT DEFAULT 0,
    `fail_reason` VARCHAR(255) DEFAULT NULL,
    `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `identifier` (`identifier`),
    KEY `stage` (`stage`),
    KEY `success` (`success`),
    KEY `completed_at` (`completed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indeksy wydajnościowe (sprawdź czy już istnieją)
CREATE INDEX IF NOT EXISTS idx_reputation_identifier ON td_tracker_reputation(identifier);
CREATE INDEX IF NOT EXISTS idx_logs_identifier ON td_tracker_logs(identifier);
CREATE INDEX IF NOT EXISTS idx_logs_completed_at ON td_tracker_logs(completed_at);

DELIMITER //

-- Procedura: Pobierz dostępne etapy dla gracza
CREATE PROCEDURE IF NOT EXISTS `sp_td_tracker_get_available_stages`(IN player_identifier VARCHAR(60))
BEGIN
    SELECT s.stage, s.name, s.min_reputation, s.chance_to_aorb, s.time_limit
    FROM td_tracker_stages s
    LEFT JOIN td_tracker_reputation r ON r.identifier = player_identifier
    WHERE s.enabled = 1
    AND (r.reputation IS NULL OR r.reputation >= s.min_reputation)
    ORDER BY s.stage ASC;
END//

-- Procedura: Pobierz konfigurację
CREATE PROCEDURE IF NOT EXISTS `sp_td_tracker_get_config`()
BEGIN
    SELECT
        config_key,
        CASE
            WHEN config_type = 'number' THEN CAST(config_value AS DECIMAL(10,2))
            WHEN config_type = 'boolean' THEN CAST(config_value AS UNSIGNED)
            ELSE config_value
        END as config_value,
        config_type
    FROM td_tracker_config;
END//

-- Procedura: Zapisz aktywną misję
CREATE PROCEDURE IF NOT EXISTS `sp_td_tracker_save_active_mission`(
    IN p_identifier VARCHAR(60),
    IN p_player_name VARCHAR(100),
    IN p_stage INT,
    IN p_tier VARCHAR(1),
    IN p_vehicle_model VARCHAR(50),
    IN p_vehicle_plate VARCHAR(10),
    IN p_data JSON
)
BEGIN
    INSERT INTO td_tracker_active_missions
    (identifier, player_name, stage, tier, vehicle_model, vehicle_plate, data)
    VALUES
    (p_identifier, p_player_name, p_stage, p_tier, p_vehicle_model, p_vehicle_plate, p_data)
    ON DUPLICATE KEY UPDATE
        stage = p_stage,
        tier = p_tier,
        vehicle_model = p_vehicle_model,
        vehicle_plate = p_vehicle_plate,
        data = p_data,
        start_time = CURRENT_TIMESTAMP;
END//

-- Procedura: Usuń aktywną misję
CREATE PROCEDURE IF NOT EXISTS `sp_td_tracker_remove_active_mission`(
    IN p_identifier VARCHAR(60)
)
BEGIN
    DELETE FROM td_tracker_active_missions WHERE identifier = p_identifier;
END//

DELIMITER ;

-- Wyczyść stare aktywne misje (starsze niż 4 godziny)
DELETE FROM td_tracker_active_missions WHERE start_time < DATE_SUB(NOW(), INTERVAL 4 HOUR);

-- Podsumowanie
SELECT 'TD Tracker Database V2 installed successfully!' as status;
SELECT COUNT(*) as total_stages FROM td_tracker_stages;
SELECT COUNT(*) as total_vehicles FROM td_tracker_vehicle_pools;
SELECT COUNT(*) as total_rewards FROM td_tracker_rewards;
SELECT COUNT(*) as total_config_items FROM td_tracker_config;
