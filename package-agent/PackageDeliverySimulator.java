import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

import org.apache.camel.BindToRegistry;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.apache.camel.component.a2a.model.Message;
import org.apache.camel.component.a2a.model.Part;
import org.apache.camel.component.a2a.model.StreamResponse;
import org.apache.camel.component.a2a.model.Task;
import org.apache.camel.component.a2a.model.TaskState;
import org.apache.camel.component.a2a.model.TaskStatus;
import org.apache.camel.component.a2a.model.TaskStatusUpdateEvent;
import org.apache.camel.component.a2a.model.TextPart;
import org.apache.camel.component.a2a.state.A2ATaskStore;

@BindToRegistry("packageDeliverySimulator")
public class PackageDeliverySimulator implements Processor {

    private static final String[] STAGES = {
            "📦 Package picked up from warehouse",
            "🚚 In transit — en route to distribution center",
            "🏪 At local distribution center",
            "🛵 Out for delivery",
            "✅ Delivered! Left at front door"
    };

    @Override
    public void process(Exchange exchange) throws Exception {
        String taskId = exchange.getIn().getHeader("CamelA2ATaskId", String.class);
        A2ATaskStore store = exchange.getProperty("CamelA2ATaskStore", A2ATaskStore.class);
        if (taskId == null || store == null) {
            return;
        }

        for (int i = 0; i < STAGES.length; i++) {
            Thread.sleep(1500 + ThreadLocalRandom.current().nextInt(3000));

            Task task = store.get(taskId);
            if (task == null) {
                return;
            }

            boolean isLast = (i == STAGES.length - 1);
            TaskState state = isLast ? TaskState.COMPLETED : TaskState.WORKING;

            TaskStatus status = new TaskStatus(state);
            Message statusMessage = new Message();
            statusMessage.setRole("agent");
            TextPart textPart = new TextPart();
            textPart.setText(STAGES[i]);
            statusMessage.setParts(List.of(textPart));
            status.setMessage(statusMessage);

            task.setStatus(status);
            store.put(taskId, task);

            TaskStatusUpdateEvent event = new TaskStatusUpdateEvent();
            event.setTaskId(taskId);
            event.setContextId(task.getContextId());
            event.setStatus(status);
            event.setIsFinal(isLast);
            store.notifySubscribers(taskId, StreamResponse.ofStatusUpdate(event));
        }

        exchange.getIn().setBody("Package delivered successfully");
    }

}
