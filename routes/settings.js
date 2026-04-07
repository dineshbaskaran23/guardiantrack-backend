'use strict';
const express = require('express');
const User    = require('../models/User');
const { protect } = require('./auth');
const router  = express.Router();

// GET /api/settings
router.get('/', protect, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('name email phone smsEnabled');
    res.json({ settings: user });
  } catch (err) {
    res.status(500).json({ error: 'Could not fetch settings' });
  }
});

// PATCH /api/settings — update profile / preferences
router.patch('/', protect, async (req, res) => {
  try {
    const allowed = ['name', 'phone', 'smsEnabled'];
    const updates = {};
    allowed.forEach(k => { if (req.body[k] !== undefined) updates[k] = req.body[k]; });

    const user = await User.findByIdAndUpdate(req.userId, updates, { new: true })
      .select('name email phone smsEnabled');
    res.json({ settings: user });
  } catch (err) {
    res.status(500).json({ error: 'Could not update settings' });
  }
});

// PATCH /api/settings/password — change password
router.patch('/password', protect, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword)
      return res.status(400).json({ error: 'currentPassword and newPassword required' });
    if (newPassword.length < 6)
      return res.status(400).json({ error: 'New password must be at least 6 characters' });

    const user = await User.findById(req.userId).select('+password');
    if (!(await user.correctPassword(currentPassword)))
      return res.status(401).json({ error: 'Current password is incorrect' });

    user.password = newPassword;
    await user.save();
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Could not update password' });
  }
});

module.exports = router;
