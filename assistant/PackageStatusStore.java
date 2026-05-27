import java.util.List;
import java.util.ArrayList;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.camel.BindToRegistry;

@BindToRegistry("packageStatusStore")
public class PackageStatusStore {

    private final ConcurrentHashMap<String, List<String>> stages = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> currentStatus = new ConcurrentHashMap<>();

    public void addStage(String taskId, String stage, String status) {
        stages.computeIfAbsent(taskId, k -> new ArrayList<>()).add(stage);
        currentStatus.put(taskId, status);
    }

    public String getStatusJson(String taskId) {
        List<String> taskStages = stages.get(taskId);
        String status = currentStatus.getOrDefault(taskId, "SUBMITTED");

        StringBuilder json = new StringBuilder();
        json.append("{\"taskId\": \"").append(escapeJson(taskId)).append("\"");
        json.append(", \"status\": \"").append(status).append("\"");

        if (taskStages != null && !taskStages.isEmpty()) {
            String latest = taskStages.get(taskStages.size() - 1);
            json.append(", \"stage\": \"").append(escapeJson(latest)).append("\"");
            json.append(", \"stages\": [");
            for (int i = 0; i < taskStages.size(); i++) {
                if (i > 0) json.append(", ");
                json.append("\"").append(escapeJson(taskStages.get(i))).append("\"");
            }
            json.append("]");
        }

        json.append("}");
        return json.toString();
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
