import { Router } from 'express';
import { Message, Task } from '@a2a-js/sdk';
import { getOidcClient } from '../services/a2a-clients.js';
import { AGENTS } from '../config.js';

const router = Router();

router.get('/api/traffic-submit', async (_req, res) => {
  try {
    const client = await getOidcClient(AGENTS.traffic);
    const result = await client.sendMessage({
      message: Message.fromJSON({
        messageId: crypto.randomUUID(),
        role: 'ROLE_USER',
        parts: [{ text: "What's my commute?" }],
      }),
      configuration: { returnImmediately: true, acceptedOutputModes: [] },
    } as any);

    // returnImmediately returns a Task
    const task = result as any;
    res.json(Task.toJSON(task));
  } catch (err: any) {
    console.error('Traffic submit error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

router.get('/api/traffic-status', async (req, res) => {
  try {
    const taskId = req.query.taskId as string;
    if (!taskId) {
      res.status(400).json({ error: 'Missing taskId' });
      return;
    }

    const client = await getOidcClient(AGENTS.traffic);
    const task = await client.getTask({ id: taskId } as any);
    res.json(Task.toJSON(task));
  } catch (err: any) {
    console.error('Traffic status error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
