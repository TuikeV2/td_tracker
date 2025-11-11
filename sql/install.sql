CREATE TABLE IF NOT EXISTS `tracker_reputation` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `reputation` INT(11) NOT NULL DEFAULT 0,
    `total_missions` INT(11) NOT NULL DEFAULT 0,
    `successful_missions` INT(11) NOT NULL DEFAULT 0,
    `failed_missions` INT(11) NOT NULL DEFAULT 0,
    `last_mission` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`),
    INDEX `idx_reputation` (`reputation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `tracker_missions` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `mission_type` INT(11) NOT NULL,
    `status` VARCHAR(20) NOT NULL,
    `reputation_gained` INT(11) NOT NULL DEFAULT 0,
    `reward_money` INT(11) NOT NULL DEFAULT 0,
    `reward_black_money` INT(11) NOT NULL DEFAULT 0,
    `duration` INT(11) NOT NULL DEFAULT 0,
    `completed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_type` (`mission_type`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `tracker_cooldowns` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `cooldown_type` VARCHAR(20) NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier_type` (`identifier`, `cooldown_type`),
    INDEX `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;