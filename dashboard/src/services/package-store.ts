const stages = new Map<string, string[]>();
const currentStatus = new Map<string, string>();

export function addStage(taskId: string, stage: string, status: string): void {
  if (!stages.has(taskId)) {
    stages.set(taskId, []);
  }
  stages.get(taskId)!.push(stage);
  currentStatus.set(taskId, status);
}

export function getStatus(taskId: string): object {
  const taskStages = stages.get(taskId) || [];
  const status = currentStatus.get(taskId) || 'UNKNOWN';
  return {
    taskId,
    status,
    stage: taskStages.length > 0 ? taskStages[taskStages.length - 1] : null,
    stages: taskStages,
  };
}
