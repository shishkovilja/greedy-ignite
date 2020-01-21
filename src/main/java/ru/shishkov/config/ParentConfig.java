package ru.shishkov.config;

import com.sun.management.OperatingSystemMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import org.apache.ignite.Ignite;
import org.apache.ignite.Ignition;
import org.apache.ignite.configuration.IgniteConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import ru.shishkov.config.util.GreedyProperties;
import ru.shishkov.config.util.HungryJob;
import ru.shishkov.config.util.OomJob;

@Configuration
public class ParentConfig {
    @Bean
    public OperatingSystemMXBean osMxBean() {
        return (OperatingSystemMXBean)ManagementFactory.getOperatingSystemMXBean();
    }

    @Bean
    public MemoryMXBean memMxBean() {
        return ManagementFactory.getMemoryMXBean();
    }

    @Bean
    public GreedyProperties appProps() {
        return new GreedyProperties();
    }

    @Bean
    public Ignite igniteInstance(IgniteConfiguration cfg) {
        return Ignition.start(cfg);
    }

    @Bean
    public HungryJob hungryJob() {
        return new HungryJob();
    }

    @Bean
    public OomJob oomJob() {
        return new OomJob();
    }
}
