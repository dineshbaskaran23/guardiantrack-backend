'use strict';
require('dotenv').config();

// ── Startup guard — fail fast with clear message ──────────────────────────────
if (!process.env.MONGO_URI) {
  console.error('❌ FATAL: MONGO_URI environment variable is not set.');
  console.error('   → Go to Render Dashboard → Your Service → Environment → Add MONGO_URI');
  process.exit(1);
}
if (!process.env.JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set.');
  process.exit(1);
}

const express     = require('express');
const http        = require('http');
const mongoose    = require('mongoose');
const cors        = require('cors');
const helmet      = require('helmet');
const morgan      = require('morgan');
const rateLimit   = require('express-rate-limit');
const { Server }  = require('socket.io');
const cron        = require('node-cron');
const logger      = require('./utils/logger');

// ── App setup ─────────────────────────────────────────────────────────────────
const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
  cors: { origin: '*', methods: ['GET','POST'] },
  pingInterval: 25000,
  pingTimeout:  60000,
});

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10kb' }));
app.use(morgan('combined', { stream: { write: msg => logger.info(msg.trim()) } }));

// Rate limiting — prevents abuse / DDoS
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 min
  max:      parseInt(process.env.RATE_LIMIT_MAX) || 100,
  message:  { error: 'Too many requests. Try again later.' },
  standardHeaders: true,
  legacyHeaders:   false,
});
app.use('/api/', limiter);

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 900000,
  max: 10,
  message: { error: 'Too many login attempts. Wait 15 minutes.' },
});
app.use('/api/auth/login', authLimiter);

// ── Database ──────────────────────────────────────────────────────────────────
mongoose.connect(process.env.MONGO_URI, {
  serverSelectionTimeoutMS: 10000,
  socketTimeoutMS: 45000,
})
.then(() => logger.info('✅ MongoDB connected'))
.catch(err => { logger.error('❌ MongoDB error:', err); process.exit(1); });

mongoose.connection.on('disconnected', () => logger.warn('⚠️  MongoDB disconnected'));
mongoose.connection.on('reconnected',  () => logger.info('♻️  MongoDB reconnected'));

// ── Socket.io ────────────────────────────────────────────────────────────────
const connectedClients = new Map(); // userId → Set of socket IDs

io.on('connection', (socket) => {
  logger.info(`Socket connected: ${socket.id}`);

  socket.on('join', (userId) => {
    socket.join(userId);
    if (!connectedClients.has(userId)) connectedClients.set(userId, new Set());
    connectedClients.get(userId).add(socket.id);
    logger.info(`User ${userId} joined room`);
  });

  socket.on('disconnect', () => {
    connectedClients.forEach((ids, uid) => {
      ids.delete(socket.id);
      if (ids.size === 0) connectedClients.delete(uid);
    });
    logger.info(`Socket disconnected: ${socket.id}`);
  });
});

// Attach io + connectedClients to app for use in routes
app.set('io', io);
app.set('connectedClients', connectedClients);

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/auth',      require('./routes/auth'));
app.use('/api/parents',   require('./routes/parents'));
app.use('/api/location',  require('./routes/location'));
app.use('/api/alerts',    require('./routes/alerts'));
app.use('/api/settings',  require('./routes/settings'));

// Health check (Render.com pings this to keep service alive)
app.get('/health', (req, res) => {
  res.json({
    status:   'ok',
    uptime:   process.uptime(),
    memory:   process.memoryUsage(),
    mongo:    mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    time:     new Date().toISOString(),
  });
});

app.get('/', (req, res) => res.json({ service: 'GuardianTrack API v1.0', status: 'running' }));

// 404 handler
app.use('*', (req, res) => res.status(404).json({ error: 'Endpoint not found' }));

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message,
  });
});

// ── CRON: Check for offline parents & missed check-ins ───────────────────────
cron.schedule('*/5 * * * *', async () => {
  try {
    const Parent     = require('./models/Parent');
    const User       = require('./models/User');
    const smsService = require('./utils/sms');

    const threshold  = new Date(Date.now() - (parseInt(process.env.OFFLINE_ALERT_MINUTES) || 15) * 60000);
    const offlinePs  = await Parent.find({ lastSeen: { $lt: threshold }, status: { $ne: 'offline' } });

    for (const p of offlinePs) {
      await Parent.findByIdAndUpdate(p._id, { status: 'offline' });
      const child = await User.findById(p.childId);
      if (child?.phone && child?.smsEnabled !== false) {
        const lastSeenStr = p.lastSeen
          ? new Date(p.lastSeen).toLocaleTimeString('en-IN')
          : 'unknown';
        await smsService.send(
          child.phone,
          `⚠️ GuardianTrack: ${p.name}'s phone went offline at ${lastSeenStr}. Last location: ${p.lastAddress || 'unknown'}. Please check on them.`
        );
        // Emit to child's app via socket
        io.to(p.childId.toString()).emit('parentOffline', { parentId: p._id, name: p.name });
      }
    }
  } catch (err) {
    logger.error('Cron error:', err);
  }
});

// ── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`🛡  GuardianTrack server running on port ${PORT}`);
  logger.info(`🌍  Environment: ${process.env.NODE_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received — shutting down gracefully');
  server.close(() => { mongoose.connection.close(); process.exit(0); });
});
