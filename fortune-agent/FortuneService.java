import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

import org.apache.camel.BindToRegistry;

@BindToRegistry("fortuneService")
public class FortuneService {

    private final List<String> fortunes;

    public FortuneService() throws Exception {
        fortunes = loadFortunes();
    }

    public String getRandomFortune() {
        return fortunes.get(ThreadLocalRandom.current().nextInt(fortunes.size()));
    }

    private List<String> loadFortunes() throws Exception {
        List<String> result = new ArrayList<>();
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("fortunes.txt");
             BufferedReader reader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {

            StringBuilder current = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                if ("%".equals(line.trim())) {
                    String fortune = current.toString().trim();
                    if (!fortune.isEmpty()) {
                        result.add(fortune);
                    }
                    current.setLength(0);
                } else {
                    if (current.length() > 0) {
                        current.append('\n');
                    }
                    current.append(line);
                }
            }
            String last = current.toString().trim();
            if (!last.isEmpty()) {
                result.add(last);
            }
        }
        return result;
    }
}
