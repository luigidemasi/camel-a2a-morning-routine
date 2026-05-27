import java.util.List;

import org.apache.camel.BindToRegistry;
import org.apache.camel.component.a2a.model.StreamResponse;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

@BindToRegistry("emailSseSerializer")
public class EmailSseSerializer {

    private static final ObjectMapper MAPPER = new ObjectMapper()
            .registerModule(new JavaTimeModule());

    @SuppressWarnings("unchecked")
    public String serialize(Object body) {
        if (!(body instanceof List)) {
            return "data: {\"error\": \"no events\"}\n\n";
        }

        List<StreamResponse> events = (List<StreamResponse>) body;
        StringBuilder sse = new StringBuilder();
        for (StreamResponse event : events) {
            try {
                sse.append("data: ").append(MAPPER.writeValueAsString(event)).append("\n\n");
            } catch (Exception e) {
                sse.append("data: {\"error\": \"serialization failed\"}\n\n");
            }
        }
        return sse.toString();
    }
}
