import java.util.ArrayList;
import java.util.List;

import org.apache.camel.AggregationStrategy;
import org.apache.camel.Exchange;

public class MorningBriefingAggregator implements AggregationStrategy {

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
            String json = """
                    {"weather": "%s", "news": "%s", "fortune": "%s"}"""
                    .formatted(
                            escapeJson(responses.get(0)),
                            escapeJson(responses.get(1)),
                            escapeJson(responses.get(2)));
            oldExchange.getIn().setBody(json);
        }

        return oldExchange;
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
