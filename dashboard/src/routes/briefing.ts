import { Router } from 'express';
import { Message, Task } from '@a2a-js/sdk';
import { getClient } from '../services/a2a-clients.js';
import { AGENTS } from '../config.js';

const router = Router();

router.get('/api/morning-briefing', async (_req, res) => {
  try {
    const client = await getClient(AGENTS.assistant);
    const result = await client.sendMessage({
      message: Message.fromJSON({
        messageId: crypto.randomUUID(),
        role: 'ROLE_USER',
        parts: [{ text: 'Give me my morning briefing' }],
      }),
    } as any);

    // Result is either a Message or a Task
    let text = '';
    if ('messageId' in result) {
      // Message response
      const msg = result as any;
      if (msg.parts?.length > 0 && msg.parts[0].content?.$case === 'text') {
        text = msg.parts[0].content.value;
      }
    } else {
      // Task response — extract from history
      const task = result as any;
      if (task.history?.length > 0) {
        const lastMsg = task.history[task.history.length - 1];
        if (lastMsg.parts?.length > 0 && lastMsg.parts[0].content?.$case === 'text') {
          text = lastMsg.parts[0].content.value;
        }
      }
    }

    // The assistant's MorningBriefingAggregator returns JSON string
    try {
      const parsed = JSON.parse(text);
      res.json(parsed);
    } catch {
      res.json({ weather: text, news: '', fortune: '' });
    }
  } catch (err: any) {
    console.error('Morning briefing error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
