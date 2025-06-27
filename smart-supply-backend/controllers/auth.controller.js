const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { createUser, findUserByEmail } = require('../models/user.model');
const pool = require('../db');

const signup = async (req, res) => {
  const { name, email, password, role, profile } = req.body; // note 'profile' not 'profileData'

  try {
    if (!profile) {
      return res.status(400).json({ message: 'Profile data is required' });
    }

    const existing = await findUserByEmail(email);
    if (existing) return res.status(400).json({ message: 'User already exists' });

    const hashed = await bcrypt.hash(password, 10);
    const user = await createUser({ name, email, password: hashed, role });
    const userId = user.id;

    switch (role) {
      case 'Supermarket':
        // Validate required supermarket fields
        if (
          !profile.store_name ||
          !profile.address ||
          !profile.license_number ||
          !profile.tax_id
        ) {
          return res.status(400).json({ message: 'Missing required supermarket profile fields' });
        }
        await pool.query(
          `INSERT INTO supermarkets (
              user_id, store_name, address, license_number, tax_id, opening_hours,
              contact_person, contact_phone, website, description
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            userId,
            profile.store_name,
            profile.address,
            profile.license_number,
            profile.tax_id,
            profile.opening_hours || null,
            profile.contact_person || null,
            profile.contact_phone || null,
            profile.website || null,
            profile.description || null,
          ]
        );
        break;

      case 'Distributor':
        if (
          !profile.company_name ||
          !profile.address ||
          !profile.phone ||
          !profile.tax_id
        ) {
          return res.status(400).json({ message: 'Missing required distributor profile fields' });
        }
        await pool.query(
          `INSERT INTO distributors 
            (user_id, company_name, address, phone, email, tax_id, license_number, description) 
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            userId,
            profile.company_name,
            profile.address,
            profile.phone,
            profile.email || email, // fallback to email from main body if profile email missing
            profile.tax_id,
            profile.license_number || null,
            profile.description || null,
          ]
        );
        break;

      case 'Delivery':
        if (
          !profile.full_name ||
          !profile.phone ||
          !profile.vehicle_type ||
          !profile.license_plate ||
          !profile.address
        ) {
          return res.status(400).json({ message: 'Missing required delivery profile fields' });
        }
        await pool.query(
          `INSERT INTO deliveries 
            (user_id, full_name, phone, vehicle_type, license_plate, address) 
          VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            userId,
            profile.full_name,
            profile.phone,
            profile.vehicle_type,
            profile.license_plate,
            profile.address,
          ]
        );
        break;

      default:
        return res.status(400).json({ message: 'Invalid role specified' });
    }

    res.status(201).json({ user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

const login = async (req, res) => {
  const { email, password } = req.body;

  try {
    const user = await findUserByEmail(email);
    if (!user) return res.status(404).json({ message: 'User not found' });

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(401).json({ message: 'Invalid password' });

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '1d' });
    res.json({ token, user: { id: user.id, name: user.name, role: user.role } });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { signup, login };
