const express = require('express');
const router = express.Router();
const PersonnelController = require('../controllers/personnelController');
const authenticate = require('../middleware/auth.middleware');

// Get all delivery personnel with detailed information
router.get('/', authenticate, PersonnelController.getAllPersonnel);

// Get personnel statistics
router.get('/stats', authenticate, PersonnelController.getPersonnelStats);

// Get detailed personnel information
router.get('/:personnelId', authenticate, PersonnelController.getPersonnelDetails);

// Get personnel performance analytics
router.get('/:personnelId/analytics', authenticate, PersonnelController.getPersonnelAnalytics);

// Add new personnel
router.post('/', authenticate, PersonnelController.addPersonnel);

// Update personnel information
router.put('/:personnelId', authenticate, PersonnelController.updatePersonnel);

// Toggle personnel availability
router.patch('/:personnelId/availability', authenticate, PersonnelController.toggleAvailability);

// Deactivate personnel
router.delete('/:personnelId', authenticate, PersonnelController.deactivatePersonnel);

// Update online status (heartbeat)
router.post('/:personnelId/heartbeat', authenticate, PersonnelController.updateOnlineStatus);

// Mark personnel as offline
router.post('/:personnelId/offline', authenticate, PersonnelController.markOffline);

module.exports = router;

