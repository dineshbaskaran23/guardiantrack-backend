'use strict';
const mongoose = require('mongoose');

const geofenceSchema = new mongoose.Schema({
  name:      { type: String, required: true },
  lat:       { type: Number, required: true },
  lng:       { type: Number, required: true },
  radiusM:   { type: Number, default: 500 },
  active:    { type: Boolean, default: true },
}, { _id: true });

const parentSchema = new mongoose.Schema({
  childId:     { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name:        { type: String, required: true, trim: true },
  phone:       { type: String, required: true, trim: true },
  deviceToken: { type: String },          // for push notifications
  status:      { type: String, enum: ['online', 'offline', 'sos'], default: 'offline' },
  battery:     { type: Number, min: 0, max: 100 },
  lastSeen:    { type: Date },
  lastLat:     { type: Number },
  lastLng:     { type: Number },
  lastAddress: { type: String },
  geofences:   [geofenceSchema],
  sosActive:   { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.model('Parent', parentSchema);
