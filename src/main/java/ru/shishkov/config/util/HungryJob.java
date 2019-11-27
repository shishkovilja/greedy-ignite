package ru.shishkov.config.util;

import com.sun.management.OperatingSystemMXBean;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import org.apache.ignite.Ignite;
import org.apache.ignite.IgniteDataStreamer;
import org.apache.ignite.IgniteLogger;
import org.apache.ignite.configuration.DataPageEvictionMode;
import org.apache.ignite.internal.processors.cache.persistence.DataRegion;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import static org.apache.ignite.configuration.DataStorageConfiguration.DFLT_PAGE_SIZE;
import static org.apache.ignite.internal.processors.cache.persistence.tree.io.AbstractDataPageIO.MIN_DATA_PAGE_OVERHEAD;

/**
 * Hungry jobs bean
 */
@Component
public class HungryJob {
    @Autowired
    private Ignite ignite;

    @Autowired
    private GreedyProperties props;

    @Autowired
    private OperatingSystemMXBean osMxBean;

    @Autowired
    private MemoryMXBean memMxBean;

    @Autowired
    private IgniteLogger log;

    /**
     * Start filling of test <q>stomach</q> cache by identical payloads (zero byte arrays of the same length).<br/> It
     * should be noted that now <em>roughly estimated</em> these values:
     * <li>
     *     <ul>maximum amount of payloads (datapages) stored in {@code maxPagesNum} variable</ul>
     *     <ul>size of {@code payload} byte array, which is set approximately accordingly comment <q>Apache Ignite will
     *     typically add around 200 bytes overhead to each entry</q> from
     *     <a href="https://apacheignite.readme.io/docs/capacity-planning#section-calculating-memory-usage">
     *         Apache Ignite documentstion
     *         </a>
     *         </ul>
     * </li>
     * <p>
     * So real end of filling process is possible due to {@link DataPageEvictionMode#RANDOM_LRU} is set for <q>default</q>
     * {@link DataRegion}.
     */
    public void performJob() {
        try (IgniteDataStreamer<Long, byte[]> streamer = ignite.dataStreamer(props.getStomachCacheName())) {
            // Payload sized with possible overhead
            byte[] payload = new byte[DFLT_PAGE_SIZE - MIN_DATA_PAGE_OVERHEAD - 200];

            long drSize = ignite.configuration()
                .getDataStorageConfiguration()
                .getDefaultDataRegionConfiguration()
                .getMaxSize();
            long maxPagesNum = drSize / DFLT_PAGE_SIZE;

            log.warning("These properties used for new greedy test: " + props);
            logSummary("Started greedy filling, trying to put %d payloads into DefaultDataRegion with size %dGB",
                maxPagesNum, drSize / 1024 / 1024 / 1024);

            long s = Math.round(props.getSubtotalsPercent() / 100 * maxPagesNum);
            long l;
            for (l = 1; l <= maxPagesNum; l++) {
                streamer.addData(l, payload);

                if (l % s == 0) {
                    logSummary("Put payloads: %d/%d (%.1f%%)",
                        l, maxPagesNum, 100.0 * l / maxPagesNum);
                }
            }

            logSummary("Greedy filling finished, put payloads: %d/%d (%.1f%%)",
                (l - 1), maxPagesNum, 100.0 * (l - 1) / maxPagesNum);
        }
        catch (Exception e) {
            log.error("Hungry Job Error", e);
        }
    }

    /**
     * Log summary message with formatted elements and show memory statistics.
     *
     * @param msg         Summary message
     * @param msgElements element print to
     */
    private void logSummary(String msg, Object... msgElements) {
        log.warning(String.format(msg, msgElements));
        logMemUsage();
    }

    /**
     * Collect and log heap and OS memory information
     */
    private void logMemUsage() {
        MemoryUsage heapUsage = memMxBean.getHeapMemoryUsage();
        long heapUsedMem = heapUsage.getUsed();
        long heapMaxMem = heapUsage.getMax();
        double heapUsagePercent = 100.0 * heapUsedMem / heapMaxMem;

        long totalOsMem = osMxBean.getTotalPhysicalMemorySize();
        long usedOsMem = totalOsMem - osMxBean.getFreePhysicalMemorySize();
        double osMemUsagePercent = 100.0 * usedOsMem / totalOsMem;

        long totalSwapSize = osMxBean.getTotalSwapSpaceSize();
        long freeSwapSize = osMxBean.getFreeSwapSpaceSize();
        long usedSwapSize = totalSwapSize - freeSwapSize;
        double usedSwapPercent = 100.0 * usedSwapSize / totalSwapSize;

        log.warning(
            String.format("Heap usage: %d/%d (%.1f%%). OS memory usage: %d/%d (%.1f%%). Swap usage: %d/%d (%.1f%%)",
                heapUsedMem, heapMaxMem, heapUsagePercent,
                usedOsMem, totalOsMem, osMemUsagePercent,
                usedSwapSize, totalSwapSize, usedSwapPercent));
    }
}
