'use strict';
const express = require('express');
const Parent  = require('../models/Parent');
const Alert   = require('../models/Alert');
const logger  = require('../utils/logger');
const { protect } = require('./auth');
const { getDistanceMeters, reverseGeocode } = require('../utils/geo');
const sms     = require('../utils/sms');
const router  = express.Router();

// POST /api/location/update — parent device posts its GPS location
router.post('/update', protect, async (req, res) => {
  try {
    const { parentId, lat, lng, battery } = req.body;
    if (!parentId || lat == null || lng == null)
      return res.status(400).json({ error: 'parentId, lat and lng required' });

    const parent = await Parent.findOne({ _id: parentId, childId: req.userId });
    if (!parent) return res.status(404).json({ error: 'Parent not found' });

    const address = await reverseGeocode(lat, lng);

    // Check geofences
    for (const gf of parent.geofences.filter(g => g.active)) {
      const dist = getDistanceMeters(lat, lng, gf.lat, gf.lng);
      const wasInside = parent.lastLat != null
        ? getDistanceMeters(parent.lastLat, parent.lastLng, gf.lat, gf.lng) <= gf.radiusM
        : true;
      const isInside = dist <= gf.radiusM;

      if (wasInside && !isInside) {
        // Exited geofence
        const msg = `📍 GuardianTrack: ${parent.name} has left ${gf.name}. Current location: ${address}`;
        await Alert.create({ childId: req.userId, parentId: parent._id, type: 'geofence_exit', message: msg, lat, lng, address });
        const io = req.app.get('io');
        io.to(req.userId.toString()).emit('geofenceExit', { parentId: parent._id, geofenceName: gf.name, address });
      }
    }

    // Battery alert
    if (battery != null && battery <= (parseInt(process.env.BATTERY_ALERT_THRESHOLD) || 20)
        && (parent.battery == null || parent.battery > (parseInt(process.env.BATTERY_ALERT_THRESHOLD) || 20))) {
      const msg = `🔋 GuardianTrack: ${parent.name}'s battery is at ${battery}%. Location: ${address}`;
      await Alert.create({ childId: req.userId, parentId: parent._id, type: 'low_battery', message: msg, lat, lng, address });
    }

    // Update parent record
    await Parent.findByIdAndUpdate(parentId, {
      lastLat: lat, lastLng: lng, lastAddress: address,
      battery, lastSeen: new Date(), status: 'online',
    });

    // Emit real-time to child's app
    const io = req.app.get('io');
    io.to(req.userId.toString()).emit('locationUpdate', { parentId, lat, lng, address, battery });

    res.json({ success: true, address });
  } catch (err) {
    logger.error('Location update error:', err);
    res.status(500).json({ error: 'Location update failed' });
  }
});

// GET /api/location/:parentId — child app fetches latest location
router.get('/:parentId', protect, async (req, res) => {
  try {
    const parent = await Parent.findOne({ _id: req.params.parentId, childId: req.userId })
      .select('name status lastLat lastLng lastAddress lastSeen battery');
    if (!parent) return res.status(404).json({ error: 'Parent not found' });
    res.json({ parent });
  } catch (err) {
    res.status(500).json({ error: 'Could not fetch location' });
  }
});

// POST /api/location/sos — parent triggers SOS
router.post('/sos', protect, async (req, res) => {
  try {
    const { parentId, lat, lng } = req.body;
    if (!parentId) return res.status(400).json({ error: 'parentId required' });

    const parent = await Parent.findOne({ _id: parentId, childId: req.userId });
    if (!parent) return res.status(404).json({ error: 'Parent not found' });

    const address = lat && lng ? await reverseGeocode(lat, lng) : parent.lastAddress || 'unknown';
    const msg = `🚨 SOS! GuardianTrack: ${parent.name} needs help! Location: ${address}`;

    await Alert.create({ childId: req.userId, parentId: parent._id, type: 'sos', message: msg, lat, lng, address });
    await Parent.findByIdAndUpdate(parentId, { sosActive: true, status: 'sos' });

    // SMS + socket
    await sms.send(parent.phone, msg);
    const io = req.app.get('io');
    io.to(req.userId.toString()).emit('sos', { parentId, name: parent.name, address, lat, lng });

    res.json({ success: true, message: 'SOS triggered' });
  } catch (err) {
    logger.error('SOS error:', err);
    res.status(500).json({ error: 'SOS failed' });
  }
});

module.exports = router;
