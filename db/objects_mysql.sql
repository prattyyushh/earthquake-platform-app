USE earthquake_db;

-- ---------------------------------------------------------------------
-- FUNCTION: classify depth
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_depth_category;
DELIMITER $$
CREATE FUNCTION fn_depth_category(p_depth DECIMAL(6,2))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE v_result VARCHAR(20);
    IF p_depth < 70 THEN
        SET v_result = 'Shallow';
    ELSEIF p_depth BETWEEN 70 AND 300 THEN
        SET v_result = 'Intermediate';
    ELSE
        SET v_result = 'Deep';
    END IF;
    RETURN v_result;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- STORED PROCEDURE: allocate a resource to an earthquake, reduce stock
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_allocate_resource;
DELIMITER $$
CREATE PROCEDURE sp_allocate_resource(
    IN p_resource_id   INT UNSIGNED,
    IN p_earthquake_id BIGINT UNSIGNED,
    IN p_quantity      INT
)
BEGIN
    DECLARE v_available INT;

    SELECT Quantity INTO v_available FROM EMERGENCY_RESOURCE WHERE ResourceID = p_resource_id;

    IF v_available IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resource does not exist';
    ELSEIF v_available < p_quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for this resource';
    END IF;

    INSERT INTO RESOURCE_ALLOCATION (AllocatedQty, AllocationDate, Status, ResourceID, EarthquakeID)
    VALUES (p_quantity, NOW(), 'Approved', p_resource_id, p_earthquake_id);

    UPDATE EMERGENCY_RESOURCE SET Quantity = Quantity - p_quantity WHERE ResourceID = p_resource_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER: auto-log any earthquake >= magnitude 7.0 into an audit table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS EARTHQUAKE_AUDIT_LOG (
    LogID        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    EarthquakeID BIGINT UNSIGNED,
    Magnitude    DECIMAL(3,1),
    LoggedAt     DATETIME DEFAULT CURRENT_TIMESTAMP,
    Note         VARCHAR(200)
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_log_major_earthquake;
DELIMITER $$
CREATE TRIGGER trg_log_major_earthquake
AFTER INSERT ON EARTHQUAKE
FOR EACH ROW
BEGIN
    IF NEW.Magnitude >= 7.0 THEN
        INSERT INTO EARTHQUAKE_AUDIT_LOG (EarthquakeID, Magnitude, Note)
        VALUES (NEW.EarthquakeID, NEW.Magnitude, 'Major earthquake (M>=7.0) auto-logged on insert');
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- TRIGGER: enforce EER specialization rule (RESEARCHER row only for Role='Researcher')
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_check_researcher_role;
DELIMITER $$
CREATE TRIGGER trg_check_researcher_role
BEFORE INSERT ON RESEARCHER
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT Role INTO v_role FROM `USER` WHERE UserID = NEW.UserID;
    IF v_role IS NULL OR v_role <> 'Researcher' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot insert into RESEARCHER: USER role does not match';
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- VIEWS
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_earthquake_overview AS
SELECT e.EarthquakeID, e.EventDateTime, e.Magnitude, e.Depth_km,
       r.RegionName, c.CountryName, c.Continent
FROM EARTHQUAKE e
JOIN REGION r  ON e.RegionID = r.RegionID
JOIN COUNTRY c ON r.CountryID = c.CountryID;

CREATE OR REPLACE VIEW vw_high_risk_regions AS
SELECT r.RegionName, c.CountryName, ra.RiskScore, ra.RiskLevel
FROM RISK_ASSESSMENT ra
JOIN REGION r ON ra.RegionID = r.RegionID
JOIN COUNTRY c ON r.CountryID = c.CountryID
WHERE ra.RiskLevel IN ('High', 'Severe');
