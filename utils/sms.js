'use strict';
const logger = require('./logger');

// Supports Twilio (international) and Fast2SMS (India — much cheaper)
async function send(toPhone, message) {
  try {
    if (process.env.USE_FAST2SMS === 'true') {
      return await sendFast2SMS(toPhone, message);
    }
    return await sendTwilio(toPhone, message);
  } catch (err) {
    logger.error('SMS send failed:', err.message);
    return { success: false, error: err.message };
  }
}

// ── Twilio ────────────────────────────────────────────────────────────────────
async function sendTwilio(toPhone, message) {
  const twilio = require('twilio')(process.env.TWILIO_SID, process.env.TWILIO_TOKEN);
  const result = await twilio.messages.create({
    body: message,
    from: process.env.TWILIO_FROM,
    to:   toPhone,
  });
  logger.info(`Twilio SMS sent: ${result.sid}`);
  return { success: true, sid: result.sid };
}

// ── Fast2SMS (India — ₹0.06–0.08/SMS) ────────────────────────────────────────
async function sendFast2SMS(toPhone, message) {
  // Strip country code for Fast2SMS (needs 10-digit Indian number)
  const mobile = toPhone.replace(/^\+91/, '').replace(/\s/g, '');

  const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
    method: 'POST',
    headers: {
      authorization: process.env.FAST2SMS_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      route:       'q',      // quick transactional
      message:     message,
      language:    'english',
      flash:       0,
      numbers:     mobile,
    }),
  });

  const data = await response.json();
  if (!data.return) throw new Error(data.message || 'Fast2SMS failed');
  logger.info(`Fast2SMS sent to ${mobile}:`, data.request_id);
  return { success: true, requestId: data.request_id };
}

module.exports = { send };
