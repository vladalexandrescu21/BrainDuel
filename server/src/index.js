'use strict';

require('dotenv').config();

const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');
const cors = require('cors');
const { registerHandlers } = require('./socket/handler');
const adminRouter = require('./routes/admin');

const PORT = process.env.PORT || 3001;

const app = express();

// Enable CORS for all origins in development
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
}));

app.use(express.json());

// Health check — before admin router so it never requires auth
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Serve static files (admin panel and other public assets)
app.use(express.static(path.join(__dirname, '..', 'public')));

// Mount admin API router
app.use('/', adminRouter);

app.get('/', (req, res) => {
  res.json({ name: 'BrainDuel Server', version: '1.0.0' });
});

const httpServer = http.createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 30000,
  pingInterval: 10000,
});

// Register all socket event handlers
registerHandlers(io);

httpServer.listen(PORT, () => {
  console.log(`[BrainDuel] Server running on port ${PORT}`);
  console.log(`[BrainDuel] SKIP_AUTH=${process.env.SKIP_AUTH || 'false'}`);
});

module.exports = { app, io };
