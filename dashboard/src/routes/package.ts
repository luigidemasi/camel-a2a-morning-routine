import { Router } from 'express';
import { Message, Task, StreamResponse } from '@a2a-js/sdk';
import { getClient } from '../services/a2a-clients.js';
import { AGENTS, BFF_WEBHOOK_URL } from '../config.js';
import { addStage, getStatus } from '../services/package-store.js';

const router = Router();

router.get('/api/package-track', async (_req, res) => {
  try {
    const client = await getClient(AGENTS.package);
    const result = await client.sendMessage({
      message: Message.fromJSON({
        messageId: crypto.randomUUID(),
        role: 'ROLE_USER',
        parts: [{ text: 'Track my package' }],
      }),
      configuration: { returnImmediately: true, acceptedOutputModes: [] },
    } as any);

    const task = result as any;
    const taskId = task.id;

    // Register push notification webhook
    await client.createTaskPushNotificationConfig({
      id: crypto.randomUUID(),
      taskId,
      url: BFF_WEBHOOK_URL,
      token: '',
      tenant: '',
      authentication: { scheme: '', credentials: '' },
    } as any);

    res.json({ taskId, status: 'SUBMITTED' });
  } catch (err: any) {
    console.error('Package track error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

router.post('/webhook/package', async (req, res) => {
  try {
    const body = req.body;
    const event = StreamResponse.fromJSON(body);

    if (event.payload?.$case === 'statusUpdate') {
      const update = event.payload.value;
      const taskId = update.taskId;
      const state = update.status?.state;

      let stageText = '';
      const msg = update.status?.message;
      if (msg?.parts?.length && msg.parts.length > 0) {
        const part = msg.parts[0];
        if (part.content?.$case === 'text') {
          stageText = part.content.value;
        }
      }

      const stateStr = state !== undefined ? taskStateToString(state) : 'UNKNOWN';
      if (stageText) {
        addStage(taskId, stageText, stateStr);
      }
    }

    res.json({ status: 'ok' });
  } catch (err: any) {
    console.error('Webhook error:', err.message);
    res.json({ status: 'ok' });
  }
});

router.get('/api/package-status', (req, res) => {
  const taskId = req.query.taskId as string;
  if (!taskId) {
    res.status(400).json({ error: 'Missing taskId' });
    return;
  }
  res.json(getStatus(taskId));
});

function taskStateToString(state: number): string {
  const names: Record<number, string> = {
    0: 'UNSPECIFIED', 1: 'SUBMITTED', 2: 'WORKING',
    3: 'COMPLETED', 4: 'FAILED', 5: 'CANCELED',
    6: 'INPUT_REQUIRED', 7: 'REJECTED', 8: 'AUTH_REQUIRED',
  };
  return names[state] || 'UNKNOWN';
}

export default router;
