const pool = require('../db');

const createUser = async (user) => {
  const { name, email, password, role } = user;
  const result = await pool.query(
    'INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, $4) RETURNING *',
    [name, email, password, role]
  );
  return result.rows[0];
};

const findUserByEmail = async (email) => {
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return result.rows[0];
};

const getUsersByRole = async (role, excludeId) => {
  let query = 'SELECT id, name, role FROM users WHERE role = $1';
  const values = [role];

  if (excludeId) {
    query += ' AND id != $2';
    values.push(excludeId);
  }

  const result = await pool.query(query, values);
  return result.rows;
};

module.exports = { createUser, findUserByEmail, getUsersByRole };
