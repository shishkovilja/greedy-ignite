package ru.shishkov.config;

import com.sun.management.OperatingSystemMXBean;
import java.lang.management.MemoryMXBean;
import org.apache.ignite.IgniteLogger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.ImportResource;
import ru.shishkov.config.util.GreedyProperties;
import ru.shishkov.config.util.Utilz;

@Configuration
@ImportResource("classpath:ignite-config-server.xml")
@Import({ParentConfig.class})
public class ServerConfig {
    @Autowired
    private GreedyProperties props;

    @Autowired
    IgniteLogger log;

    @Bean
    public Long regionSize(OperatingSystemMXBean osMxBean, MemoryMXBean memMxBean) {
        long regSz = 0;

        try {
            regSz = Utilz.estimateDataRegionSize(
                Utilz.availableMemory(osMxBean, memMxBean),
                props.getEatRatioProp(),
                props.getEatSizeProp());
        }
        catch (Exception e) {
            log.error("Region size estimation error", e);
        }

        return regSz;
    }
}
