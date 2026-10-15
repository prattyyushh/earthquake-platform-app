const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend')));

const JWT_SECRET = process.env.JWT_SECRET || 'da3-demo-secret-change-me';

const pool = mysql.createPool({
  host: 'localhost',
  user: 'eq_app',
  password: 'eq_app_pw',
  database: 'earthquake_db',
  waitForConnections: true,
  connectionLimit: 10,
});

// -----------------------------------------------------------------
// Auth middleware — Security / User Roles
// -----------------------------------------------------------------
function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'No token provided' });
  const token = header.replace('Bearer ', '');
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: `Requires role: ${roles.join(' or ')}` });
    }
    next();
  };
}

// -----------------------------------------------------------------
// AUTH
// -----------------------------------------------------------------
app.post('/api/auth/register', async (req, res) => {
  const { name, email, password, role } = req.body;
  if (!name || !email || !password || !role) return res.status(400).json({ error: 'Missing fields' });
  try {
    const hash = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO `USER` (Name, Email, PasswordHash, Role) VALUES (?, ?, ?, ?)',
      [name, email, hash, role]
    );
    const userId = result.insertId;
    if (role === 'Public') await pool.query('INSERT INTO PUBLIC_USER (UserID) VALUES (?)', [userId]);
    else if (role === 'Researcher') await pool.query('INSERT INTO RESEARCHER (UserID) VALUES (?)', [userId]);
    else if (role === 'Responder') await pool.query('INSERT INTO EMERGENCY_RESPONDER (UserID) VALUES (?)', [userId]);
    else if (role === 'Admin') await pool.query('INSERT INTO SYSTEM_ADMIN (UserID) VALUES (?)', [userId]);
    res.json({ userId, name, email, role });
  } catch (e) {
    res.status(400).json({ error: e.sqlMessage || e.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const [rows] = await pool.query('SELECT * FROM `USER` WHERE Email = ?', [email]);
  if (rows.length === 0) return res.status(401).json({ error: 'Invalid credentials' });
  const user = rows[0];
  const ok = await bcrypt.compare(password, user.PasswordHash);
  if (!ok) return res.status(401).json({ error: 'Invalid credentials' });
  const token = jwt.sign({ userId: user.UserID, role: user.Role, name: user.Name }, JWT_SECRET, { expiresIn: '8h' });
  res.json({ token, user: { userId: user.UserID, name: user.Name, role: user.Role } });
});

// -----------------------------------------------------------------
// EARTHQUAKES — CRUD
// -----------------------------------------------------------------
app.get('/api/earthquakes', async (req, res) => {
  const { minMagnitude, regionId, lat, lng, radiusDeg } = req.query;
  let sql = `SELECT e.*, r.RegionName, c.CountryName FROM EARTHQUAKE e
             LEFT JOIN REGION r ON e.RegionID = r.RegionID
             LEFT JOIN COUNTRY c ON r.CountryID = c.CountryID WHERE 1=1`;
  const params = [];
  if (minMagnitude) { sql += ' AND e.Magnitude >= ?'; params.push(minMagnitude); }
  if (regionId) { sql += ' AND e.RegionID = ?'; params.push(regionId); }
  if (lat && lng && radiusDeg) {
    sql += ' AND e.Latitude BETWEEN ? AND ? AND e.Longitude BETWEEN ? AND ?';
    params.push(Number(lat) - Number(radiusDeg), Number(lat) + Number(radiusDeg),
                Number(lng) - Number(radiusDeg), Number(lng) + Number(radiusDeg));
  }
  sql += ' ORDER BY e.EventDateTime DESC';
  const [rows] = await pool.query(sql, params);
  res.json(rows);
});

app.get('/api/earthquakes/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM EARTHQUAKE WHERE EarthquakeID = ?', [req.params.id]);
  if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
});

app.post('/api/earthquakes', authenticate, requireRole('Admin', 'Researcher'), async (req, res) => {
  const { eventDateTime, magnitude, magnitudeType, depthKm, latitude, longitude, sourceAgency, regionId, faultId } = req.body;
  try {
    const [result] = await pool.query(
      `INSERT INTO EARTHQUAKE (EventDateTime, Magnitude, MagnitudeType, Depth_km, Latitude, Longitude, SourceAgency, RegionID, FaultID)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [eventDateTime, magnitude, magnitudeType, depthKm, latitude, longitude, sourceAgency, regionId || null, faultId || null]
    );
    res.status(201).json({ earthquakeId: result.insertId });
  } catch (e) {
    res.status(400).json({ error: e.sqlMessage || e.message });
  }
});

app.put('/api/earthquakes/:id', authenticate, requireRole('Admin', 'Researcher'), async (req, res) => {
  const { magnitude, depthKm, sourceAgency } = req.body;
  await pool.query('UPDATE EARTHQUAKE SET Magnitude = COALESCE(?,Magnitude), Depth_km = COALESCE(?,Depth_km), SourceAgency = COALESCE(?,SourceAgency) WHERE EarthquakeID = ?',
    [magnitude, depthKm, sourceAgency, req.params.id]);
  res.json({ updated: true });
});

app.delete('/api/earthquakes/:id', authenticate, requireRole('Admin'), async (req, res) => {
  await pool.query('DELETE FROM EARTHQUAKE WHERE EarthquakeID = ?', [req.params.id]);
  res.json({ deleted: true });
});

// -----------------------------------------------------------------
// REPORTS — Joins / Nested Queries / Aggregates / Views
// -----------------------------------------------------------------
app.get('/api/reports/region-risk', async (req, res) => {
  const [rows] = await pool.query(`
    SELECT r.RegionName, c.CountryName, ra.RiskScore, ra.RiskLevel
    FROM RISK_ASSESSMENT ra
    JOIN REGION r ON ra.RegionID = r.RegionID
    JOIN COUNTRY c ON r.CountryID = c.CountryID
    ORDER BY ra.RiskScore DESC`);
  res.json(rows);
});

app.get('/api/reports/above-average-risk', async (req, res) => {
  const [rows] = await pool.query(`
    SELECT RegionName FROM REGION
    WHERE RegionID IN (
      SELECT RegionID FROM RISK_ASSESSMENT
      WHERE RiskScore > (SELECT AVG(RiskScore) FROM RISK_ASSESSMENT)
    )`);
  res.json(rows);
});

app.get('/api/reports/stats-by-region', async (req, res) => {
  const [rows] = await pool.query(`
    SELECT r.RegionName, COUNT(e.EarthquakeID) AS event_count, ROUND(AVG(e.Magnitude),2) AS avg_magnitude
    FROM REGION r JOIN EARTHQUAKE e ON r.RegionID = e.RegionID
    GROUP BY r.RegionName ORDER BY avg_magnitude DESC`);
  res.json(rows);
});

app.get('/api/views/earthquake-overview', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM vw_earthquake_overview ORDER BY Magnitude DESC');
  res.json(rows);
});

app.get('/api/views/high-risk-regions', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM vw_high_risk_regions ORDER BY RiskScore DESC');
  res.json(rows);
});

// -----------------------------------------------------------------
// DASHBOARD — aggregates for visualization
// -----------------------------------------------------------------
app.get('/api/dashboard/stats', async (req, res) => {
  const [[totals]] = await pool.query(
    'SELECT COUNT(*) AS total, ROUND(AVG(Magnitude),2) AS avgMag, MAX(Magnitude) AS maxMag FROM EARTHQUAKE');
  const [byRegion] = await pool.query(`
    SELECT r.RegionName, COUNT(*) AS count FROM EARTHQUAKE e
    JOIN REGION r ON e.RegionID=r.RegionID GROUP BY r.RegionName`);
  const [byResourceType] = await pool.query(`
    SELECT er.ResourceType, SUM(ra.AllocatedQty) AS total
    FROM RESOURCE_ALLOCATION ra JOIN EMERGENCY_RESOURCE er ON ra.ResourceID=er.ResourceID
    GROUP BY er.ResourceType`);
  const [magnitudeDist] = await pool.query(`
    SELECT FLOOR(Magnitude) AS magBucket, COUNT(*) AS count FROM EARTHQUAKE GROUP BY FLOOR(Magnitude) ORDER BY magBucket`);
  res.json({ totals, byRegion, byResourceType, magnitudeDist });
});

// -----------------------------------------------------------------
// STORED PROCEDURE call — resource allocation
// -----------------------------------------------------------------
app.post('/api/allocate-resource', authenticate, requireRole('Admin', 'Responder'), async (req, res) => {
  const { resourceId, earthquakeId, quantity } = req.body;
  try {
    await pool.query('CALL sp_allocate_resource(?, ?, ?)', [resourceId, earthquakeId, quantity]);
    res.json({ allocated: true });
  } catch (e) {
    res.status(400).json({ error: e.sqlMessage || e.message });
  }
});

// -----------------------------------------------------------------
// Audit log — Admin only (security demo)
// -----------------------------------------------------------------
app.get('/api/audit-log', authenticate, requireRole('Admin'), async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM EARTHQUAKE_AUDIT_LOG ORDER BY LoggedAt DESC');
  res.json(rows);
});

// -----------------------------------------------------------------
// Reference data for dropdowns
// -----------------------------------------------------------------
app.get('/api/regions', async (req, res) => {
  const [rows] = await pool.query('SELECT RegionID, RegionName FROM REGION');
  res.json(rows);
});
app.get('/api/resources', async (req, res) => {
  const [rows] = await pool.query('SELECT ResourceID, ResourceType, Quantity, Location, Status FROM EMERGENCY_RESOURCE');
  res.json(rows);
});

app.get('/api/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`Earthquake Platform API running on http://localhost:${PORT}`));
