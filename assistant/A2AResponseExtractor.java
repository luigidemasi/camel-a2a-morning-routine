import java.util.List;

import org.apache.camel.Exchange;
import org.apache.camel.spi.SimpleFunction;
import org.apache.camel.BindToRegistry;
import org.apache.camel.component.a2a.model.Message;
import org.apache.camel.component.a2a.model.Part;
import org.apache.camel.component.a2a.model.Task;
import org.apache.camel.component.a2a.model.TextPart;

/**
 * Extracts text from an A2A Task or Message response.
 *
 * Usage in Simple expression: ${body} ~> ${a2aText()}
 */
@BindToRegistry("a2a-text-function")
public class A2AResponseExtractor implements SimpleFunction {

    @Override
    public String getName() {
        return "a2aText";
    }

    @Override
    public Object apply(Exchange exchange, Object input) throws Exception {
        if (input instanceof Task) {
            return extractFromTask((Task) input);
        } else if (input instanceof Message) {
            return extractFromMessage((Message) input);
        }
        return input != null ? input.toString() : "";
    }

    private String extractFromTask(Task task) {
        List<Message> history = task.getHistory();
        if (history != null && !history.isEmpty()) {
            return extractFromMessage(history.get(history.size() - 1));
        }
        return "";
    }

    private String extractFromMessage(Message message) {
        List<Part> parts = message.getParts();
        if (parts != null) {
            for (Part part : parts) {
                if (part instanceof TextPart) {
                    return ((TextPart) part).getText();
                }
            }
        }
        return "";
    }
}
