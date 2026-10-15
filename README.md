# Global Earthquake Monitoring and Risk Analysis Platform — DA3 Build

A working, full-stack implementation of the project: MySQL 8 database +
Express/Node.js REST API + a browser dashboard. This is what you demo live.

## 1. Prerequisites

- MySQL 8.0+ installed and running
- Node.js 18+ and npm installed

## 2. Database setup (run once)

```bash
mysql -u root -p < db/schema_mysql.sql     # creates the database + 15 tables
mysql -u root -p < db/objects_mysql.sql    # functions, procedures, triggers, views
mysql -u root -p < db/data_mysql.sql       # real historical earthquake dataset
```

Then create the app's own DB user (don't run the app as root):
```sql
CREATE USER 'eq_app'@'localhost' IDENTIFIED BY 'eq_app_pw';
GRANT ALL PRIVILEGES ON earthquake_db.* TO 'eq_app'@'localhost';
FLUSH PRIVILEGES;
```
(If you use a different username/password, edit the `pool = mysql.createPool({...})` block near the top of `backend/server.js`.)

## 3. Run the app

```bash
cd backend
npm install
node server.js
```
Then open **http://localhost:4000** in a browser. The backend serves the
dashboard itself — one process, one port, nothing else to configure.

## 4. Demo accounts (real bcrypt-hashed passwords, ready to use)

| Email | Password | Role |
|---|---|---|
| priya@example.com | admin123 | Admin |
| carlos@example.com | responder123 | Responder |
| kenji@example.com | research123 | Researcher |
| asha@example.com | public123 | Public |

Log in as different roles during the demo to show the access-control
differences (see §6).

## 5. What's actually implemented (maps to the DA3 checklist)

| DA3 requirement | Where it lives |
|---|---|
| Front-end/application | `frontend/index.html` — single-page dashboard |
| Database connectivity | `backend/server.js` via `mysql2` connection pool |
| Data insertion | "Earthquakes" tab → Add Earthquake form (Admin/Researcher) |
| Data retrieval | Dashboard stats, Earthquakes table, Reports tab |
| Update & Delete | `PUT`/`DELETE /api/earthquakes/:id` (Delete is Admin-only, wired into the UI) |
| SQL queries | every `/api/*` route — see `server.js` |
| Joins | `/api/reports/region-risk`, `/api/dashboard/stats` |
| Nested Queries | `/api/reports/above-average-risk` (subquery with `IN` + `AVG`) |
| Aggregate Functions | `/api/reports/stats-by-region` (`COUNT`, `AVG`), dashboard totals (`MAX`) |
| Views | `vw_earthquake_overview`, `vw_high_risk_regions` — "Views" tab |
| Stored Procedures | `sp_allocate_resource` — Admin/Responder "Admin" tab |
| Functions | `fn_depth_category` (used server-side; query it directly in MySQL for the demo too) |
| Triggers | `trg_log_major_earthquake` (auto-fills audit log), `trg_check_researcher_role` (enforces EER specialization) |
| Dashboard / Visualization | Chart.js bar/doughnut charts on the Dashboard tab |
| Security / User Roles | JWT auth + role middleware — see §6 |
| Testing & error handling | See §7 |

## 6. Security / Role-Based Access — what to actually demo

- Try `DELETE` on an earthquake while logged out → **401 Unauthorized**
- Log in as `asha@example.com` (Public) and try the same → **403 Forbidden**
- Log in as `priya@example.com` (Admin) → delete succeeds, and the Admin tab's
  audit log becomes visible
- Log in as `carlos@example.com` (Responder) → can allocate resources
  (calls `sp_allocate_resource`) but cannot see the audit log (Admin-only)
- Passwords are bcrypt-hashed (never stored in plaintext); sessions are
  stateless JWTs with an 8-hour expiry

## 7. Testing performed (document this in your report / be ready to repeat live)

Every endpoint and database object listed above was tested directly
against a live instance before being included in this build:
- Schema: all 15 tables created with zero errors (**note:** an earlier
  version using `SERIAL` for primary keys against plain `INT` foreign
  keys failed with MySQL error 3780 — type mismatch. Fixed by giving
  every PK/FK pair an explicit, identical type — see the comment at the
  top of `schema_mysql.sql`. Worth mentioning in the viva as a concrete
  debugging example.)
- Function `fn_depth_category`: verified Shallow/Intermediate/Deep output
- Procedure `sp_allocate_resource`: verified it reduces stock and inserts
  an allocation row; verified it rejects over-allocation
- Trigger `trg_log_major_earthquake`: verified a M≥7.0 insert auto-populates the audit log
- Trigger `trg_check_researcher_role`: verified it rejects a RESEARCHER
  row for a non-Researcher user
- Auth/roles: verified 401 (no token), 403 (wrong role), 200 (correct
  role) for every protected route

## 8. Known limitations / honest "Future Scope" talking points

- No cloud deployment — runs locally (fine for a live demo; mention
  AWS RDS / cloud MySQL as future scope if the rubric expects a cloud answer)
- Indexing exists (lat/long, datetime, magnitude) but no formal query
  performance benchmarking was done — if asked, propose `EXPLAIN
  ANALYZE` on the location-search query as the next step
- No NoSQL component — propose MongoDB for raw sensor waveform storage
  as future scope (matches the "Spatial database / Time-series data /
  SQL + MongoDB" idea from the original project brief)
- The "near me" search uses a simple lat/long bounding box, not true
  geodesic distance — PostGIS/MySQL spatial functions are the natural upgrade

## 9. Folder structure

```
db/
  schema_mysql.sql    - CREATE DATABASE + all 15 tables
  objects_mysql.sql   - functions, procedures, triggers, views
  data_mysql.sql      - real historical earthquake dataset + demo users
backend/
  server.js           - Express API (also serves the frontend)
  package.json
frontend/
  index.html          - the whole dashboard (vanilla JS + Chart.js)
```
