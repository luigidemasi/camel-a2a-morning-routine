import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.camel.AggregationStrategy;
import org.apache.camel.Exchange;

public class MorningBriefingAggregator implements AggregationStrategy {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Override
    public Exchange aggregate(Exchange oldExchange, Exchange newExchange) {
        if (oldExchange == null) {
            List<String> responses = new ArrayList<>();
            responses.add(newExchange.getIn().getBody(String.class));
            newExchange.setProperty("responses", responses);
            return newExchange;
        }

        @SuppressWarnings("unchecked")
        List<String> responses = oldExchange.getProperty("responses", List.class);
        responses.add(newExchange.getIn().getBody(String.class));

        if (responses.size() == 3) {
            try {
                Map<String, String> result = new LinkedHashMap<>();
                result.put("weather", responses.get(0));
                result.put("news", responses.get(1));
                result.put("fortune", responses.get(2));
                oldExchange.getIn().setBody(MAPPER.writeValueAsString(result));
            } catch (Exception e) {
                throw new RuntimeException("Failed to serialize briefing", e);
            }
        }

        return oldExchange;
    }
}
