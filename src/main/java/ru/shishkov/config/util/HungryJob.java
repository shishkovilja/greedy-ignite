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
    // TODO Add autocalculation for KB, MB, GB, TB etc.
    public static final long GIGABYTE = 1L << 30;

    public static final int MIN_SLEEP_DURATION = 15;

    public static final long BYTES_BETWEEN_LAZY_SLEEPS = 1L << 28;

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
            int payloadSz = DFLT_PAGE_SIZE - MIN_DATA_PAGE_OVERHEAD - 200;
            byte[] payload = new byte[payloadSz];

            long drSize = ignite.configuration()
                .getDataStorageConfiguration()
                .getDefaultDataRegionConfiguration()
                .getMaxSize();

            double gigabytesInPage = (double)DFLT_PAGE_SIZE / GIGABYTE;
            long pagesNum = drSize / DFLT_PAGE_SIZE;
            long totalPutVolume = Math.round(pagesNum * gigabytesInPage);

            long subtotalsStep = Math.round(props.getSubtotalsPercent() / 100.0 * pagesNum);
            long payloadsBetweenSleeps = BYTES_BETWEEN_LAZY_SLEEPS / payloadSz;

            log.warning("These properties used for new greedy test: " + props);
            logSummary("Started greedy filling, trying to put %d payloads, total used memory should be %dGB",
                pagesNum, totalPutVolume);

            long startMillis = System.currentTimeMillis();
            long previousStartMillis = startMillis;
            long sleepPausesCnt = 0;
            long activeIntervalsSum = 0;

            long payloadsCnt;

            for (payloadsCnt = 1; payloadsCnt <= pagesNum; payloadsCnt++) {
                streamer.addData(payloadsCnt, payload);

                if (payloadsCnt % subtotalsStep == 0) {
                    double progressPercent = 100.0 * payloadsCnt / pagesNum;
                    long putVolume = Math.round(payloadsCnt * gigabytesInPage);

                    logSummary("Put payloads: %d(~%dGB)/%d(~%dGB) (%.1f%%)",
                            payloadsCnt, putVolume, pagesNum, totalPutVolume, progressPercent);
                }

                // Sleep in case of lazy mode
                if (props.getLaziness() > 1.0 && payloadsCnt % payloadsBetweenSleeps == 0) {
                    long curJobDuration = System.currentTimeMillis() - previousStartMillis;
                    long avgJobDuration = (curJobDuration + activeIntervalsSum) / (sleepPausesCnt + 1);

                    long curSleepDuration = Math.round(avgJobDuration * (props.getLaziness() - 1.0));

                    if (curSleepDuration >= MIN_SLEEP_DURATION) {
                        Thread.sleep(curSleepDuration);

                        sleepPausesCnt++;
                        activeIntervalsSum += curJobDuration;

                        previousStartMillis = System.currentTimeMillis();
                    }
                }
            }

            double durationSeconds = (System.currentTimeMillis() - startMillis) / 1000.0;

            long putVolume = Math.round((payloadsCnt - 1) * gigabytesInPage);

            logSummary("Greedy filling finished in %.2f seconds, put payloads: %d(~%dGB)/%d(~%dGB)",
                durationSeconds, payloadsCnt - 1, putVolume, pagesNum, totalPutVolume);
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
