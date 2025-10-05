const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'GP',
  password: 'dawud',
  port: 5432,
  ssl: false,
});

module.exports = pool;
