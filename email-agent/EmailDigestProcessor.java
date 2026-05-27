import java.util.List;

import org.apache.camel.BindToRegistry;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.apache.camel.component.a2a.model.Message;
import org.apache.camel.component.a2a.model.TaskState;
import org.apache.camel.component.a2a.model.TextPart;
import org.apache.camel.component.a2a.streaming.A2AStreamEmitter;

@BindToRegistry("emailDigestProcessor")
public class EmailDigestProcessor implements Processor {

    @Override
    public void process(Exchange exchange) throws Exception {
        A2AStreamEmitter emitter = exchange.getIn().getHeader(
                "CamelA2AStreamEmitter", A2AStreamEmitter.class);

        if (emitter != null && !emitter.isClosed()) {
            emitter.emitStatus(TaskState.WORKING, "📧 Connecting to inbox...");
            Thread.sleep(1500);
            emitter.emitStatus(TaskState.WORKING, "📬 Found 12 unread messages...");
            Thread.sleep(1500);
            emitter.emitStatus(TaskState.WORKING, "🔍 Prioritizing by sender and subject...");
            Thread.sleep(1500);
            emitter.emitStatus(TaskState.WORKING, "⚡ 3 urgent, 5 normal, 4 low priority");
            Thread.sleep(1000);

            String digest =
                "📧 Email Digest:\n" +
                "⚡ URGENT:\n" +
                "  1. 🔴 VP Engineering — Q3 planning meeting moved to 10am\n" +
                "  2. 🔴 Security Team — Critical patch deployment today\n" +
                "  3. 🔴 HR — Benefits enrollment deadline tomorrow\n\n" +
                "📋 NORMAL:\n" +
                "  4. Project Atlas — Sprint review notes\n" +
                "  5. Design Team — New mockups ready for review\n" +
                "  6. DevOps — Kubernetes upgrade scheduled\n" +
                "  7. Marketing — Newsletter draft for approval\n" +
                "  8. Finance — Expense report reminder\n\n" +
                "📭 LOW:\n" +
                "  9. Community — Open source meetup next week\n" +
                "  10. Newsletter — Tech digest weekly\n" +
                "  11. Alerts — 4 GitHub notifications\n" +
                "  12. Promo — Cloud credits expiring";

            Message digestMsg = new Message();
            digestMsg.setRole("agent");
            digestMsg.setParts(List.of(new TextPart(digest)));
            emitter.emitMessage(digestMsg);
        }

        exchange.getIn().setBody("done");
    }
}
