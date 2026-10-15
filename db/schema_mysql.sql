-- =====================================================================
-- Global Earthquake Monitoring and Risk Analysis Platform
-- MySQL 8.0 schema (corrected for strict FK type matching)
--
-- NOTE on the fix: MySQL's SERIAL is actually shorthand for
-- "BIGINT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE". If a primary key
-- uses SERIAL but the column referencing it is declared a plain INT,
-- MySQL's InnoDB engine rejects the foreign key (error 3780) because
-- the two column types don't match exactly in type/size/signedness.
-- Every PK/FK pair below is declared with the identical explicit type
-- on both sides to avoid this.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS earthquake_db;
USE earthquake_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS ALERT_SUBSCRIPTION;
DROP TABLE IF EXISTS SYSTEM_ADMIN;
DROP TABLE IF EXISTS EMERGENCY_RESPONDER;
DROP TABLE IF EXISTS RESEARCHER;
DROP TABLE IF EXISTS PUBLIC_USER;
DROP TABLE IF EXISTS `USER`;
DROP TABLE IF EXISTS RESOURCE_ALLOCATION;
DROP TABLE IF EXISTS EMERGENCY_RESOURCE;
DROP TABLE IF EXISTS RISK_ASSESSMENT;
DROP TABLE IF EXISTS SENSOR_READING;
DROP TABLE IF EXISTS SEISMIC_STATION;
DROP TABLE IF EXISTS EARTHQUAKE;
DROP TABLE IF EXISTS FAULT_LINE;
DROP TABLE IF EXISTS REGION;
DROP TABLE IF EXISTS COUNTRY;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE COUNTRY (
    CountryID      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    CountryName    VARCHAR(100) NOT NULL,
    ISOCode        CHAR(3) NOT NULL UNIQUE,
    Continent      VARCHAR(30) NOT NULL,
    Population     BIGINT CHECK (Population >= 0)
) ENGINE=InnoDB;

CREATE TABLE REGION (
    RegionID          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    RegionName        VARCHAR(100) NOT NULL,
    CountryID         INT UNSIGNED NOT NULL,
    SeismicZoneClass  VARCHAR(20) CHECK (SeismicZoneClass IN ('Low','Moderate','High','Very High')),
    FOREIGN KEY (CountryID) REFERENCES COUNTRY(CountryID)
) ENGINE=InnoDB;

CREATE TABLE FAULT_LINE (
    FaultID     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    FaultName   VARCHAR(100) NOT NULL,
    FaultType   VARCHAR(30) CHECK (FaultType IN ('Normal','Reverse','Strike-Slip','Thrust')),
    Length_km   DECIMAL(7,2) CHECK (Length_km > 0),
    SlipRate    DECIMAL(5,2),
    RegionID    INT UNSIGNED NOT NULL,
    FOREIGN KEY (RegionID) REFERENCES REGION(RegionID)
) ENGINE=InnoDB;

CREATE TABLE EARTHQUAKE (
    EarthquakeID    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    EventDateTime   DATETIME NOT NULL,
    Magnitude       DECIMAL(3,1) NOT NULL CHECK (Magnitude BETWEEN 0 AND 10),
    MagnitudeType   VARCHAR(10) CHECK (MagnitudeType IN ('Mw','Ms','Mb','ML')),
    Depth_km        DECIMAL(6,2) NOT NULL CHECK (Depth_km >= 0),
    Latitude        DECIMAL(9,6) NOT NULL,
    Longitude       DECIMAL(9,6) NOT NULL,
    SourceAgency    VARCHAR(50) NOT NULL,
    RegionID        INT UNSIGNED,
    FaultID         INT UNSIGNED,
    FOREIGN KEY (RegionID) REFERENCES REGION(RegionID),
    FOREIGN KEY (FaultID) REFERENCES FAULT_LINE(FaultID)
) ENGINE=InnoDB;

CREATE TABLE SEISMIC_STATION (
    StationID      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    StationName    VARCHAR(100) NOT NULL,
    Latitude       DECIMAL(9,6) NOT NULL,
    Longitude      DECIMAL(9,6) NOT NULL,
    Elevation      DECIMAL(7,2),
    InstalledDate  DATE NOT NULL,
    RegionID       INT UNSIGNED NOT NULL,
    FOREIGN KEY (RegionID) REFERENCES REGION(RegionID)
) ENGINE=InnoDB;

CREATE TABLE SENSOR_READING (
    ReadingID     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `Timestamp`   DATETIME NOT NULL,
    PGA           DECIMAL(6,4),
    PGV           DECIMAL(6,4),
    StationID     INT UNSIGNED NOT NULL,
    EarthquakeID  BIGINT UNSIGNED,
    FOREIGN KEY (StationID) REFERENCES SEISMIC_STATION(StationID),
    FOREIGN KEY (EarthquakeID) REFERENCES EARTHQUAKE(EarthquakeID),
    UNIQUE (StationID, `Timestamp`)
) ENGINE=InnoDB;

CREATE TABLE RISK_ASSESSMENT (
    RiskID          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    RiskScore       DECIMAL(5,2) CHECK (RiskScore BETWEEN 0 AND 100),
    RiskLevel       VARCHAR(15) CHECK (RiskLevel IN ('Low','Moderate','High','Severe')),
    AssessmentDate  DATE NOT NULL,
    ModelVersion    VARCHAR(20) NOT NULL,
    RegionID        INT UNSIGNED NOT NULL,
    FOREIGN KEY (RegionID) REFERENCES REGION(RegionID)
) ENGINE=InnoDB;

CREATE TABLE EMERGENCY_RESOURCE (
    ResourceID    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ResourceType  VARCHAR(30) CHECK (ResourceType IN ('Medical','Rescue','Shelter','Food','Water')),
    Quantity      INT CHECK (Quantity >= 0),
    Location      VARCHAR(150) NOT NULL,
    Status        VARCHAR(15) CHECK (Status IN ('Available','Deployed','Depleted')),
    RegionID      INT UNSIGNED NOT NULL,
    FOREIGN KEY (RegionID) REFERENCES REGION(RegionID)
) ENGINE=InnoDB;

CREATE TABLE RESOURCE_ALLOCATION (
    AllocationID    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    AllocatedQty    INT CHECK (AllocatedQty > 0),
    AllocationDate  DATETIME NOT NULL,
    Status          VARCHAR(15) CHECK (Status IN ('Requested','Approved','Dispatched','Closed')),
    ResourceID      INT UNSIGNED NOT NULL,
    EarthquakeID    BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (ResourceID) REFERENCES EMERGENCY_RESOURCE(ResourceID),
    FOREIGN KEY (EarthquakeID) REFERENCES EARTHQUAKE(EarthquakeID)
) ENGINE=InnoDB;

CREATE TABLE `USER` (
    UserID          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    Name            VARCHAR(100) NOT NULL,
    Email           VARCHAR(100) NOT NULL UNIQUE,
    PasswordHash    VARCHAR(255) NOT NULL,
    Role            VARCHAR(20) CHECK (Role IN ('Public','Researcher','Responder','Admin')),
    RegisteredDate  DATE NOT NULL DEFAULT (CURRENT_DATE)
) ENGINE=InnoDB;

CREATE TABLE PUBLIC_USER (
    UserID          INT UNSIGNED PRIMARY KEY,
    PreferredRegion INT UNSIGNED,
    FOREIGN KEY (UserID) REFERENCES `USER`(UserID),
    FOREIGN KEY (PreferredRegion) REFERENCES REGION(RegionID)
) ENGINE=InnoDB;

CREATE TABLE RESEARCHER (
    UserID        INT UNSIGNED PRIMARY KEY,
    Institution   VARCHAR(150),
    ResearchArea  VARCHAR(100),
    FOREIGN KEY (UserID) REFERENCES `USER`(UserID)
) ENGINE=InnoDB;

CREATE TABLE EMERGENCY_RESPONDER (
    UserID       INT UNSIGNED PRIMARY KEY,
    Agency       VARCHAR(150),
    Jurisdiction VARCHAR(100),
    FOREIGN KEY (UserID) REFERENCES `USER`(UserID)
) ENGINE=InnoDB;

CREATE TABLE SYSTEM_ADMIN (
    UserID      INT UNSIGNED PRIMARY KEY,
    AccessLevel VARCHAR(20),
    FOREIGN KEY (UserID) REFERENCES `USER`(UserID)
) ENGINE=InnoDB;

CREATE TABLE ALERT_SUBSCRIPTION (
    SubscriptionID  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    AlertType       VARCHAR(20) CHECK (AlertType IN ('SMS','Email','Push')),
    Threshold       DECIMAL(3,1) CHECK (Threshold BETWEEN 0 AND 10),
    Status          VARCHAR(10) CHECK (Status IN ('Active','Paused')),
    UserID          INT UNSIGNED NOT NULL,
    RegionID        INT UNSIGNED NOT NULL,
    FOREIGN KEY (UserID) REFERENCES `USER`(UserID),
    FOREIGN KEY (RegionID) REFERENCES REGION(RegionID)
) ENGINE=InnoDB;

CREATE INDEX idx_earthquake_latlong ON EARTHQUAKE (Latitude, Longitude);
CREATE INDEX idx_earthquake_datetime ON EARTHQUAKE (EventDateTime);
CREATE INDEX idx_earthquake_magnitude ON EARTHQUAKE (Magnitude);
CREATE INDEX idx_reading_station_time ON SENSOR_READING (StationID, `Timestamp`);
CREATE INDEX idx_region_country ON REGION (CountryID);
