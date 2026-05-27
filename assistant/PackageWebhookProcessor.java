import org.apache.camel.BindToRegistry;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.apache.camel.component.a2a.model.Message;
import org.apache.camel.component.a2a.model.Part;
import org.apache.camel.component.a2a.model.StreamResponse;
import org.apache.camel.component.a2a.model.TextPart;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@BindToRegistry("packageWebhookProcessor")
public class PackageWebhookProcessor implements Processor {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule());

    @Override
    public void process(Exchange exchange) throws Exception {
        String body = exchange.getIn().getBody(String.class);
        if (body == null || body.isBlank()) {
            return;
        }

        StreamResponse event = MAPPER.readValue(body, StreamResponse.class);
        if (event.getStatusUpdate() == null) {
            return;
        }

        String taskId = event.getStatusUpdate().getTaskId();
        String status = "WORKING";
        String stage = "";

        if (event.getStatusUpdate().getStatus() != null) {
            if (event.getStatusUpdate().getStatus().getState() != null) {
                status = event.getStatusUpdate().getStatus().getState().name();
            }
            Message msg = event.getStatusUpdate().getStatus().getMessage();
            if (msg != null && msg.getParts() != null) {
                for (Part part : msg.getParts()) {
                    if (part instanceof TextPart) {
                        stage = ((TextPart) part).getText();
                        break;
                    }
                }
            }
        }

        PackageStatusStore store = exchange.getContext()
                .getRegistry().lookupByNameAndType("packageStatusStore", PackageStatusStore.class);
        if (store != null && taskId != null) {
            store.addStage(taskId, stage, status);
        }
    }
}
