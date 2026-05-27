import java.util.List;

import org.apache.camel.BindToRegistry;
import org.apache.camel.component.a2a.model.Message;
import org.apache.camel.component.a2a.model.Part;
import org.apache.camel.component.a2a.model.Task;
import org.apache.camel.component.a2a.model.TaskState;
import org.apache.camel.component.a2a.model.TextPart;

@BindToRegistry("trafficStatusExtractor")
public class TrafficStatusExtractor {

    public String extractStatus(Task task) {
        String id = task.getId();
        TaskState state = task.getStatus() != null ? task.getStatus().getState() : null;
        String stateName = state != null ? state.name() : "UNKNOWN";
        String result = "";

        if (state == TaskState.COMPLETED) {
            result = extractText(task);
        }

        return "{\"taskId\": \"" + escapeJson(id) + "\", \"status\": \"" + stateName + "\""
                + (state == TaskState.COMPLETED ? ", \"result\": \"" + escapeJson(result) + "\"" : "")
                + "}";
    }

    private String extractText(Task task) {
        List<Message> history = task.getHistory();
        if (history != null && !history.isEmpty()) {
            Message last = history.get(history.size() - 1);
            List<Part> parts = last.getParts();
            if (parts != null) {
                for (Part part : parts) {
                    if (part instanceof TextPart) {
                        return ((TextPart) part).getText();
                    }
                }
            }
        }
        return "";
    }

    private String escapeJson(String text) {
        if (text == null) {
            return "";
        }
        return text.replace("\\", "\\\\")
                   .replace("\"", "\\\"")
                   .replace("\n", "\\n")
                   .replace("\r", "\\r")
                   .replace("\t", "\\t");
    }
}
