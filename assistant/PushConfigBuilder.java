import org.apache.camel.BindToRegistry;
import org.apache.camel.component.a2a.model.TaskPushNotificationConfig;

@BindToRegistry("pushConfigBuilder")
public class PushConfigBuilder {

    public TaskPushNotificationConfig build() {
        TaskPushNotificationConfig config = new TaskPushNotificationConfig();
        config.setUrl("http://localhost:8090/package-webhook");
        return config;
    }
}
