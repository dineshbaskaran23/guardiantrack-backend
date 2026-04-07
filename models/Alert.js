'use strict';
const mongoose = require('mongoose');

const alertSchema = new mongoose.Schema({
  childId:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  parentId:  { type: mongoose.Schema.Types.ObjectId, ref: 'Parent' },
  type:      { type: String, enum: ['sos', 'geofence_exit', 'geofence_enter', 'low_battery', 'offline'], required: true },
  message:   { type: String, required: true },
  lat:       { type: Number },
  lng:       { type: Number },
  address:   { type: String },
  read:      { type: Boolean, default: false },
}, { timestamps: true });

module.exports = mongoose.model('Alert', alertSchema);
