import { Router } from 'express';
import { Message, StreamResponse } from '@a2a-js/sdk';
import { getClient } from '../services/a2a-clients.js';
import { AGENTS } from '../config.js';

const router = Router();

router.get('/api/email-stream', async (_req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  try {
    const client = await getClient(AGENTS.email);
    const message = Message.fromJSON({
      messageId: crypto.randomUUID(),
      role: 'ROLE_USER',
      parts: [{ text: 'Show me my email digest' }],
    });

    for await (const event of client.sendMessageStream({ message } as any)) {
      const json = JSON.stringify(StreamResponse.toJSON(event));
      res.write(`data: ${json}\n\n`);
    }
  } catch (err: any) {
    console.error('Email stream error:', err.message);
    const errorEvent = JSON.stringify({ error: err.message });
    res.write(`event: error\ndata: ${errorEvent}\n\n`);
  } finally {
    res.write('event: done\ndata: {}\n\n');
    res.end();
  }
});

export default router;
