import java.io.InputStream;
import java.nio.charset.StandardCharsets;

import org.apache.camel.BindToRegistry;

@BindToRegistry("dashboardPage")
public class DashboardPage {

    private final String html;

    public DashboardPage() throws Exception {
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("dashboard.html")) {
            html = new String(is.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    public String getHtml() {
        return html;
    }
}
