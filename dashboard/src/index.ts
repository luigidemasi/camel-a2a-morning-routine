import express from 'express';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { BFF_PORT } from './config.js';
import briefingRouter from './routes/briefing.js';
import emailRouter from './routes/email.js';
import trafficRouter from './routes/traffic.js';
import packageRouter from './routes/package.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

const app = express();

app.use(express.json({ type: ['application/json', 'application/a2a+json'] }));
app.use(express.static(join(__dirname, '..', 'public')));

app.use(briefingRouter);
app.use(emailRouter);
app.use(trafficRouter);
app.use(packageRouter);

app.get('/', (_req, res) => {
  res.sendFile(join(__dirname, '..', 'public', 'dashboard.html'));
});

app.listen(BFF_PORT, () => {
  console.log(`Dashboard BFF listening on http://localhost:${BFF_PORT}`);
});
