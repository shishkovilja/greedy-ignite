package ru.shishkov.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.ImportResource;
import ru.shishkov.config.util.GreedyProperties;

@Configuration
@ImportResource("classpath:config/ignite-config-client.xml")
@Import({ParentConfig.class})
public class ClientConfig {

    @Autowired
    private GreedyProperties props;
}
