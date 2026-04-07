'use strict';

// Haversine formula — returns distance in metres
function getDistanceMeters(lat1, lng1, lat2, lng2) {
  const R   = 6371000;
  const f1  = lat1 * Math.PI / 180;
  const f2  = lat2 * Math.PI / 180;
  const df  = (lat2 - lat1) * Math.PI / 180;
  const dl  = (lng2 - lng1) * Math.PI / 180;
  const a   = Math.sin(df/2)**2 + Math.cos(f1) * Math.cos(f2) * Math.sin(dl/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Free reverse geocode using Nominatim (OpenStreetMap) — no API key needed
async function reverseGeocode(lat, lng) {
  try {
    const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`;
    const res = await fetch(url, {
      headers: { 'User-Agent': 'GuardianTrack/1.0' },
    });
    const data = await res.json();
    const a    = data.address || {};
    const parts = [
      a.road || a.pedestrian || a.street,
      a.suburb || a.neighbourhood || a.village,
      a.city || a.town || a.county,
      a.state,
    ].filter(Boolean);
    return parts.join(', ') || data.display_name || `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
  } catch {
    return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
  }
}

module.exports = { getDistanceMeters, reverseGeocode };
