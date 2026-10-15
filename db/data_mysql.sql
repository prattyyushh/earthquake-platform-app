USE earthquake_db;

INSERT INTO COUNTRY (CountryName, ISOCode, Continent, Population) VALUES
('Japan', 'JPN', 'Asia', 125000000),
('Nepal', 'NPL', 'Asia', 30000000),
('Chile', 'CHL', 'South America', 19600000),
('Turkey', 'TUR', 'Asia', 85000000),
('Indonesia', 'IDN', 'Asia', 275000000),
('India', 'IND', 'Asia', 1428000000),
('Haiti', 'HTI', 'North America', 11400000);

INSERT INTO REGION (RegionName, CountryID, SeismicZoneClass) VALUES
('Tohoku', 1, 'Very High'),
('Gorkha', 2, 'Very High'),
('Maule', 3, 'Very High'),
('East Anatolia', 4, 'High'),
('Aceh', 5, 'Very High'),
('Kutch', 6, 'High'),
('Ouest', 7, 'High');

INSERT INTO FAULT_LINE (FaultName, FaultType, Length_km, SlipRate, RegionID) VALUES
('Japan Trench', 'Thrust', 800.00, 8.00, 1),
('Main Frontal Thrust', 'Thrust', 2400.00, 18.00, 2),
('Peru-Chile Trench', 'Thrust', 5900.00, 7.00, 3),
('East Anatolian Fault', 'Strike-Slip', 700.00, 10.00, 4),
('Sunda Megathrust', 'Thrust', 5500.00, 6.00, 5),
('Kutch Mainland Fault', 'Reverse', 200.00, 0.50, 6),
('Enriquillo-Plantain Garden Fault', 'Strike-Slip', 300.00, 7.00, 7);

INSERT INTO EARTHQUAKE (EventDateTime, Magnitude, MagnitudeType, Depth_km, Latitude, Longitude, SourceAgency, RegionID, FaultID) VALUES
('2011-03-11 05:46:24', 9.1, 'Mw', 29.0,  38.297,  142.373, 'USGS', 1, 1),
('2015-04-25 06:11:26', 7.8, 'Mw',  8.2,  28.147,   84.708, 'USGS', 2, 2),
('2010-02-27 06:34:14', 8.8, 'Mw', 22.9, -36.122,  -72.898, 'USGS', 3, 3),
('2023-02-06 01:17:34', 7.8, 'Mw', 17.9,  37.174,   37.032, 'USGS', 4, 4),
('2004-12-26 00:58:53', 9.1, 'Mw', 30.0,   3.295,   95.982, 'USGS', 5, 5),
('2001-01-26 03:16:40', 7.7, 'Mw', 16.0,  23.419,   70.232, 'USGS', 6, 6),
('2010-01-12 21:53:10', 7.0, 'Mw', 13.0,  18.443,  -72.571, 'USGS', 7, 7);

INSERT INTO SEISMIC_STATION (StationName, Latitude, Longitude, Elevation, InstalledDate, RegionID) VALUES
('MYGH-01', 38.30, 141.00, 120.0, '2005-04-01', 1),
('KTMU-02', 27.70,  85.32, 1400.0,'2008-11-12', 2),
('SANT-03', -33.45, -70.66, 520.0,'2003-06-20', 3),
('GAZI-04', 37.06,  37.38, 570.0, '2012-03-15', 4);

INSERT INTO SENSOR_READING (`Timestamp`, PGA, PGV, StationID, EarthquakeID) VALUES
('2011-03-11 05:46:30', 0.5610, 34.2000, 1, 1),
('2015-04-25 06:11:32', 0.1830,  9.4000, 2, 2),
('2010-02-27 06:34:20', 0.6500, 30.1000, 3, 3),
('2023-02-06 01:17:40', 0.7000, 28.5000, 4, 4);

INSERT INTO RISK_ASSESSMENT (RiskScore, RiskLevel, AssessmentDate, ModelVersion, RegionID) VALUES
(95.00, 'Severe', '2026-08-01', 'v1.3', 1),
(88.00, 'Severe', '2026-08-01', 'v1.3', 2),
(90.00, 'Severe', '2026-08-01', 'v1.3', 3),
(80.00, 'High',   '2026-08-01', 'v1.3', 4),
(93.00, 'Severe', '2026-08-01', 'v1.3', 5),
(70.00, 'High',   '2026-08-01', 'v1.3', 6),
(72.00, 'High',   '2026-08-01', 'v1.3', 7);

INSERT INTO EMERGENCY_RESOURCE (ResourceType, Quantity, Location, Status, RegionID) VALUES
('Medical', 100, 'Sendai Depot', 'Available', 1),
('Rescue',   40, 'Kathmandu Depot', 'Available', 2),
('Shelter', 200, 'Concepcion Depot', 'Available', 3),
('Medical',  60, 'Gaziantep Depot', 'Deployed', 4),
('Food',    150, 'Banda Aceh Depot', 'Available', 5);

INSERT INTO RESOURCE_ALLOCATION (AllocatedQty, AllocationDate, Status, ResourceID, EarthquakeID) VALUES
(30, '2011-03-11 08:00:00', 'Dispatched', 1, 1),
(15, '2015-04-25 09:00:00', 'Dispatched', 2, 2),
(50, '2010-02-27 10:00:00', 'Dispatched', 3, 3),
(20, '2023-02-06 04:00:00', 'Dispatched', 4, 4);

-- Password hashes below are real bcrypt hashes (cost 10) of these plaintext
-- demo passwords, so you can actually log in through the app:
--   asha@example.com    / public123     (Public)
--   kenji@example.com   / research123   (Researcher)
--   carlos@example.com  / responder123  (Responder)
--   priya@example.com   / admin123      (Admin)
INSERT INTO `USER` (Name, Email, PasswordHash, Role) VALUES
('Asha Rao', 'asha@example.com', '$2a$10$k78nYvU85wgG9/uymIQVCubdri5z9zA6VQggWAn6VPE7TfFhNqbV.', 'Public'),
('Dr. Kenji Sato', 'kenji@example.com', '$2a$10$uLScE5kQR0BIGU4oL88/.OLsHoAnV5lhIHGDGT68gF3jKKz/VFDpC', 'Researcher'),
('Carlos Munoz', 'carlos@example.com', '$2a$10$GkFFXP30oHbuic/jhQ/7..oc16UOZuXOVD.DLfDRv.WkfEsioiNhG', 'Responder'),
('Priya Nair', 'priya@example.com', '$2a$10$phcqqezgA3PMlzoudkDk1ebguebyWaONFagKmZCSnB9LyivhHnRQK', 'Admin');

INSERT INTO PUBLIC_USER (UserID, PreferredRegion) VALUES (1, 1);
INSERT INTO RESEARCHER (UserID, Institution, ResearchArea) VALUES (2, 'Univ. of Tokyo', 'Seismology');
INSERT INTO EMERGENCY_RESPONDER (UserID, Agency, Jurisdiction) VALUES (3, 'ONEMI Chile', 'Maule Region');
INSERT INTO SYSTEM_ADMIN (UserID, AccessLevel) VALUES (4, 'Super Admin');

INSERT INTO ALERT_SUBSCRIPTION (AlertType, Threshold, Status, UserID, RegionID) VALUES
('Email', 6.0, 'Active', 1, 1),
('SMS',   7.0, 'Active', 2, 2),
('Push',  7.5, 'Active', 3, 3);
