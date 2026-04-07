'use strict';
const express = require('express');
const Alert   = require('../models/Alert');
const { protect } = require('./auth');
const router  = express.Router();

// GET /api/alerts — get all alerts for logged-in child
router.get('/', protect, async (req, res) => {
  try {
    const { limit = 50, unread } = req.query;
    const filter = { childId: req.userId };
    if (unread === 'true') filter.read = false;

    const alerts = await Alert.find(filter)
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .select('-__v');
    res.json({ alerts, unreadCount: await Alert.countDocuments({ childId: req.userId, read: false }) });
  } catch (err) {
    res.status(500).json({ error: 'Could not fetch alerts' });
  }
});

// PATCH /api/alerts/:id/read — mark single alert as read
router.patch('/:id/read', protect, async (req, res) => {
  try {
    await Alert.findOneAndUpdate({ _id: req.params.id, childId: req.userId }, { read: true });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Could not mark alert as read' });
  }
});

// PATCH /api/alerts/read-all — mark all alerts as read
router.patch('/read-all', protect, async (req, res) => {
  try {
    await Alert.updateMany({ childId: req.userId, read: false }, { read: true });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Could not mark alerts as read' });
  }
});

// DELETE /api/alerts/:id — delete a single alert
router.delete('/:id', protect, async (req, res) => {
  try {
    await Alert.findOneAndDelete({ _id: req.params.id, childId: req.userId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Could not delete alert' });
  }
});

module.exports = router;
