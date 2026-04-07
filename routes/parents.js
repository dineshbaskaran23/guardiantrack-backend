'use strict';
const express = require('express');
const Parent  = require('../models/Parent');
const logger  = require('../utils/logger');
const { protect } = require('./auth');
const router  = express.Router();

// GET /api/parents — list all parents linked to the logged-in child
router.get('/', protect, async (req, res) => {
  try {
    const parents = await Parent.find({ childId: req.userId }).select('-__v');
    res.json({ parents });
  } catch (err) {
    logger.error('Get parents error:', err);
    res.status(500).json({ error: 'Could not fetch parents' });
  }
});

// POST /api/parents — add a new parent
router.post('/', protect, async (req, res) => {
  try {
    const { name, phone } = req.body;
    if (!name || !phone)
      return res.status(400).json({ error: 'name and phone are required' });

    const parent = await Parent.create({ childId: req.userId, name, phone });
    logger.info(`Parent added: ${name} for child ${req.userId}`);
    res.status(201).json({ parent });
  } catch (err) {
    logger.error('Add parent error:', err);
    res.status(500).json({ error: 'Could not add parent' });
  }
});

// DELETE /api/parents/:id — remove a parent
router.delete('/:id', protect, async (req, res) => {
  try {
    const parent = await Parent.findOneAndDelete({ _id: req.params.id, childId: req.userId });
    if (!parent) return res.status(404).json({ error: 'Parent not found' });
    res.json({ message: 'Parent removed' });
  } catch (err) {
    res.status(500).json({ error: 'Could not remove parent' });
  }
});

// POST /api/parents/:id/geofence — add a geofence to a parent
router.post('/:id/geofence', protect, async (req, res) => {
  try {
    const { name, lat, lng, radiusM } = req.body;
    if (!name || !lat || !lng)
      return res.status(400).json({ error: 'name, lat and lng required' });

    const parent = await Parent.findOneAndUpdate(
      { _id: req.params.id, childId: req.userId },
      { $push: { geofences: { name, lat, lng, radiusM: radiusM || 500 } } },
      { new: true }
    );
    if (!parent) return res.status(404).json({ error: 'Parent not found' });
    res.json({ parent });
  } catch (err) {
    res.status(500).json({ error: 'Could not add geofence' });
  }
});

module.exports = router;
