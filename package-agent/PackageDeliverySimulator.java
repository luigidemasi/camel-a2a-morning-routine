import java.util.concurrent.ThreadLocalRandom;

import org.apache.camel.BindToRegistry;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.apache.camel.component.a2a.A2AProgress;

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
        for (String stage : STAGES) {
            Thread.sleep(1500 + ThreadLocalRandom.current().nextInt(3000));
            A2AProgress.emit(exchange, stage);
        }
        exchange.getMessage().setBody("Package delivered successfully");
    }

}
