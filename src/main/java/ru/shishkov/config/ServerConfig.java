package ru.shishkov.config;

import com.sun.management.OperatingSystemMXBean;
import org.apache.ignite.IgniteLogger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.ImportResource;
import ru.shishkov.config.util.GreedyProperties;

import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.util.Optional;

// TODO available size should take into account NON-DEFAULT values of internal ignite variables (system and TxRegion, etc.)

/**
 * Server configuration bean. Import of external XML is used.
 */
@Configuration
@ImportResource("classpath:config/ignite-config-server.xml")
@Import({ParentConfig.class})
public class ServerConfig {
    /**
     * Logger.
     */
    @Autowired
    IgniteLogger log;

    /**
     * Properties.
     */
    @Autowired
    private GreedyProperties props;

    /**
     * @param osMxBean  Os mx bean.
     * @param memMxBean Mem mx bean.
     */
    @Bean
    public Long alternateRegionSize(OperatingSystemMXBean osMxBean, MemoryMXBean memMxBean) {
        Optional<Long> regSz = Optional.empty();

        try {
            regSz = alternateDataRegionSize(props, osMxBean, memMxBean);

            if (!regSz.isPresent())
                throw new IllegalArgumentException("Empty region size obtained!");
        } catch (Exception e) {
            log.error("Region size estimation error", e);
            System.exit(-1);
        }

        return regSz.get();
    }

    /**
     * Get region size according to given properties and available memory for DataRegion.
     *
     * @param props     {@link GreedyProperties} containing nessesary system properties.
     * @param osMxBean  {@link OperatingSystemMXBean} instance to get info about operating memory.
     * @param memMxBean {@link MemoryMXBean} instance to get info about JVM memory.
     * @return calculated memory size.
     * @throws IllegalArgumentException in case if incorrect properties passed via JVM arguments.
     */
    private Optional<Long> alternateDataRegionSize(GreedyProperties props,
                                                   OperatingSystemMXBean osMxBean, MemoryMXBean memMxBean) {
        Optional<Long> retVal = Optional.empty();

        MemoryUsage heapMemUsage = memMxBean.getHeapMemoryUsage();

        long freeOsMem = osMxBean.getFreePhysicalMemorySize();
        long totalOsMem = osMxBean.getTotalPhysicalMemorySize();

        // See max size of SysCache in DataStorageConfiguration#DFLT_SYS_REG_MAX_SIZE
        long DFLT_SYS_REG_MAX_SIZE = 100L * 1024 * 1024;

        //See DataRegionConfiguration#evictionThreshold
        double evictionThreshold = 0.9;

        // + additional TxLog region, see MvccProcessorImpl#createTxLogRegion max size equal to DFLT_SYS_REG_MAX_SIZE
        long availMem = freeOsMem - DFLT_SYS_REG_MAX_SIZE * 2;

        long xmx = heapMemUsage.getMax();

        if (availMem < 0)
            throw new IllegalStateException(String.format("Heap max size (Xmx) should be less than free OS memory" +
                            " at least to 200MB: heap max size: %dMB, free OS memory: %dMB", xmx / (1 << 20),
                    (freeOsMem + xmx) / (1 << 20)));

        double eatRatio = props.getEatRatio();

        long overEatTotal = props.getOverEatSz() * 1024 * 1024 * 1024 + availMem;

        if (Double.isFinite(eatRatio) && eatRatio > 0.0) {
            long eatThreshold = Math.round(eatRatio * totalOsMem / 100.0 / evictionThreshold);

            if (eatThreshold > totalOsMem - availMem)
                retVal = Optional.of(eatThreshold - (totalOsMem - availMem));
            else
                throw new IllegalArgumentException(String.format("'eat.ratio' is too low, so eat memory threshold " +
                                "%dMB is less than used memory in OS: %dMB (heap included: %dMB)",
                        eatThreshold / (1 << 20), (totalOsMem - availMem) / (1 << 20),
                        xmx / (1 << 20)));
        } else if (overEatTotal >= availMem)
            retVal = Optional.of(overEatTotal);
        else if (props.getEatSz() <= 0)
            throw new IllegalArgumentException("'eat.ratio' property value should be correct positive double " +
                    "or correct positive values for could be set 'eat.size' (in bytes) or 'over.eat.size' " +
                    "(in gigabytes");

        return retVal;
    }
}
