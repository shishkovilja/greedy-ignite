package ru.shishkov;

import com.sun.management.OperatingSystemMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryUsage;
import org.apache.ignite.Ignite;
import org.apache.ignite.IgniteCheckedException;
import org.apache.ignite.IgniteDataStreamer;
import org.apache.ignite.IgniteLogger;
import org.apache.ignite.Ignition;
import org.apache.ignite.cache.eviction.EvictionPolicy;
import org.apache.ignite.configuration.DataPageEvictionMode;
import org.apache.ignite.configuration.DataRegionConfiguration;
import org.apache.ignite.configuration.DataStorageConfiguration;
import org.apache.ignite.configuration.IgniteConfiguration;
import org.apache.ignite.internal.IgniteEx;
import org.apache.ignite.internal.pagemem.PageIdAllocator;
import org.apache.ignite.internal.pagemem.PageMemory;
import org.apache.ignite.internal.processors.cache.GridCacheUtils;
import org.apache.ignite.internal.processors.cache.persistence.DataRegion;
import org.apache.ignite.internal.processors.cache.persistence.pagemem.PageMemoryEx;
import org.apache.ignite.internal.processors.cache.persistence.tree.io.DataPageIO;
import org.apache.ignite.internal.processors.cache.persistence.tree.io.PageIO;
import org.apache.ignite.logger.log4j.Log4JLogger;
import org.apache.ignite.spi.discovery.DiscoverySpi;
import org.apache.ignite.spi.discovery.tcp.TcpDiscoverySpi;

import static org.apache.ignite.configuration.DataStorageConfiguration.DFLT_PAGE_SIZE;
import static org.apache.ignite.internal.processors.cache.persistence.tree.io.AbstractDataPageIO.MIN_DATA_PAGE_OVERHEAD;
import static org.apache.ignite.internal.processors.cache.persistence.tree.io.PageIO.T_DATA;

/**
 * Test is developed to check Apache Ignite behaviour when it uses memory more than operating system has.
 */
public class IgniteMemoryOvercommitTest {
    public static final String STOMACH_CACHE = "stomach";
    private double initMemRatio;
    private double maxMemRatio;
    private long initMemSz;
    private long maxMemSz;
    private long maxPagesNum;

    public IgniteMemoryOvercommitTest() {
        processSystemProps();
        initMemVals();
    }

    public static void main(String[] args) {
        Thread.currentThread().setName(IgniteMemoryOvercommitTest.class.getSimpleName());
        doTest();
    }

    /**
     * Start ignite and perform test.
     */
    // TODO Remove forcing of checkpoint
    private static void doTest() {
        IgniteMemoryOvercommitTest overcommitTest = new IgniteMemoryOvercommitTest();
        Ignite ignite = overcommitTest.startIgnite();

        try {
            IgniteEx igniteEx = (IgniteEx)ignite;

            PageMemory pageMem = igniteEx.context().cache().context().database()
                .dataRegion("default").pageMemory();

            overcommitTest.startFilling(ignite, pageMem, 10.0);

//            overcommitTest.startEating(ignite, pageMem, 1.0);

//            ignite.log().info("Forcing checkpoint after all");
//            GridCacheDatabaseSharedManager db = (GridCacheDatabaseSharedManager)igniteEx.context()
//                .cache().context().database();
//            db.waitForCheckpoint("Hungry test");
//            ignite.log().info("Hungry test finished with checkpoint correctly");
        }
        catch (IgniteCheckedException e) {
            e.printStackTrace();
        }
    }

    /**
     * Get necessary system properties.
     */
    //TODO add activity and verbosity
    private void processSystemProps() {
        initMemRatio = processPositiveDoubleProp("init.ratio", "50.0");
        maxMemRatio = processPositiveDoubleProp("max.ratio", "50.0");
    }

    /**
     * Utility methood or obtaining double values of desired system properties via {@link System#getProperty(String,
     * String)}.
     *
     * @param prop    name of obtained property
     * @param dfltVal default value, in case of property is not set
     * @return double value of property
     */
    private double processPositiveDoubleProp(String prop, String dfltVal) {
        double retVal;

        try {
            retVal = Double.parseDouble(System.getProperty(prop, dfltVal));

            if (retVal <= 0.0)
                throw new IllegalArgumentException("Property '" + prop + "' should be positive non-zero integer");
        }
        catch (NumberFormatException e) {
            throw new IllegalArgumentException("Property '" + prop + "' should be correct integer value", e);
        }

        return retVal;
    }

    /**
     * Set-up variables, used for further configuration of <q>default</q> {@link DataRegion}, filled during test.
     * Maximum size of DataRegion with taking to account JVM heap size, and default values of Ignite's system region max
     * size, and TxLog data region max size (equal to Ignite system region max size).
     */
    private void initMemVals() {
        long freeOsMem = ((OperatingSystemMXBean)ManagementFactory.getOperatingSystemMXBean())
            .getFreePhysicalMemorySize();
        long offheapMaxSize = Runtime.getRuntime().maxMemory();

        // See max size of SysCache in DataStorageConfiguration#DFLT_SYS_REG_MAX_SIZE
        long DFLT_SYS_REG_MAX_SIZE = 100L * 1024 * 1024;

        // + additional TxLog region, see MvccProcessorImpl#createTxLogRegion max size equal to DFLT_SYS_REG_MAX_SIZE
        long freeMem = freeOsMem - offheapMaxSize - DFLT_SYS_REG_MAX_SIZE * 2;

        initMemSz = Math.round(freeMem * initMemRatio / 100);
        maxMemSz = Math.round(freeMem * maxMemRatio / 100);

        maxPagesNum = maxMemSz / DFLT_PAGE_SIZE;
    }

    /**
     * Configure and start ignite, create test cache.
     *
     * @return Started {@link Ignite} instance.
     */
    private Ignite startIgnite() {
        Ignite ignite = Ignition.start(getIgniteCfg());

        // TODO Remove on case of persistence support removal
//        ignite.cluster().active(true);

        ignite.getOrCreateCache(STOMACH_CACHE);

        return ignite;
    }

    /**
     * Prepare connfiguration for Ignite, including:
     * <li>
     *     <ul><q>default</q> {@link DataRegionConfiguration} sizes and percistence mode</ul>
     *     <ul>{@link DiscoverySpi}</ul>
     *     <ul>{@link IgniteLogger}</ul>
     * </li>
     *
     * @return prepared {@link IgniteConfiguration}
     */
    // TODO Ignite should be configured via XML, because of it's greater durability
    @Deprecated
    private IgniteConfiguration getIgniteCfg() {
        if (initMemSz <= 0 || maxMemSz <= 0)
            throw new IllegalArgumentException("Max or min memory size should be more then zero");

        IgniteLogger log = null;
        try {
            log = new Log4JLogger(getClass().getClassLoader().getResource("log4j.xml"));
        }
        catch (IgniteCheckedException e) {
            e.printStackTrace();
        }

        DataStorageConfiguration dsCfg = new DataStorageConfiguration();
        dsCfg.getDefaultDataRegionConfiguration()

// TODO Add options (properties) to turn on/off persistence
//            .setPersistenceEnabled(true)

            .setInitialSize(initMemSz)
            .setMaxSize(maxMemSz)
            .setPageEvictionMode(DataPageEvictionMode.RANDOM_LRU);

        TcpDiscoverySpi spi = new TcpDiscoverySpi();
        spi.setLocalAddress("127.0.0.1");

        return new IgniteConfiguration()
            .setDataStorageConfiguration(dsCfg)
            .setDiscoverySpi(spi)
            .setGridLogger(log);
    }

    /**
     * Fill directly on server node through low level API of page memory. Process needs <em>persistence to be turned
     * on.</em> Pages are allocated by means of {@link PageMemoryEx} and initialized written by {@link PageIO} and
     * {@link DataPageIO}
     *
     * @param ignite           {@link Ignite} server instance, should NOT be in client mode
     * @param pageMem          {@link PageMemory} instance, used to allocate pages
     * @param subtotalsPercent percent at which subtotals information is logged
     * @throws IgniteCheckedException
     */
    @Deprecated
    private void startEating(Ignite ignite, PageMemory pageMem, double subtotalsPercent) throws IgniteCheckedException {
        PageMemoryEx pageMemEx = (PageMemoryEx)pageMem;
        IgniteLogger log = ignite.log();

        logSummary(log, "Started hungry eating, trying to eat %d pages", maxPagesNum);

        byte[] payload = new byte[DFLT_PAGE_SIZE - MIN_DATA_PAGE_OVERHEAD];
        long s = Math.round(subtotalsPercent / 100 * maxPagesNum);

        long l;
        for (l = 1; l <= maxPagesNum; l++) {
            eatDataPage(pageMemEx, payload);

            if (l % s == 0) {
                logSummary(log, "Eaten pages: %d/%d (%.1f%%). Loaded pages in PageMemory: %d",
                    l, maxPagesNum, 100.0 * l / maxPagesNum, pageMemEx.loadedPages());
            }
        }

        logSummary(log, "Hungry eating finished, eaten pages: %d/%d (%.1f%%). Loaded pages in PageMemory: %d",
            (l - 1), maxPagesNum, 100.0 * (l - 1) / maxPagesNum, pageMemEx.loadedPages());
    }

    /**
     * Alocate, init and fill (write row) data page with payload byte array.
     *
     * @param mem     {@link PageMemoryEx}, used to allocate pages
     * @param payload bytes of payload
     * @throws IgniteCheckedException
     */
    @Deprecated
    private void eatDataPage(PageMemoryEx mem, byte[] payload) throws IgniteCheckedException {
        int cacheId = GridCacheUtils.cacheId(STOMACH_CACHE);
        long pageId = mem.allocatePage(cacheId, 0, PageIdAllocator.FLAG_DATA);

        DataPageIO io = PageIO.getPageIO(T_DATA, 1);

        long pageAddr = mem.acquirePage(cacheId, pageId);

        try {
            io.initNewPage(pageAddr, pageId, DFLT_PAGE_SIZE);
            io.addRow(pageAddr, payload, DFLT_PAGE_SIZE);
        }
        finally {
            mem.releasePage(cacheId, pageId, pageAddr);
        }
    }

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
     * So real end of filling process is possible due to {@link EvictionPolicy} is set for <q>default</q>
     * {@link DataRegion}.
     *
     * @param ignite           {@link Ignite} instance, could be client node
     * @param pageMem          {@link PageMemory} instance, used to show loaded pages amount
     * @param subtotalsPercent percent at which subtotals information is logged
     */
    private void startFilling(Ignite ignite, PageMemory pageMem, double subtotalsPercent) {
        try (IgniteDataStreamer<Long, byte[]> streamer = ignite.dataStreamer(STOMACH_CACHE)) {
            // Payload sized with possible overhead
            byte[] payload = new byte[DFLT_PAGE_SIZE - MIN_DATA_PAGE_OVERHEAD - 200];

            IgniteLogger log = ignite.log();

            logSummary(log, "Started hungry filling, trying to put %d payloads", maxPagesNum);

            long s = Math.round(subtotalsPercent / 100 * maxPagesNum);
            long l;
            for (l = 1; l <= maxPagesNum; l++) {
                streamer.addData(l, payload);

                if (l % s == 0) {
                    logSummary(log, "Put payloads: %d/%d (%.1f%%). Loaded pages in PageMemory: %d",
                        l, maxPagesNum, 100.0 * l / maxPagesNum, pageMem.loadedPages());
                }
            }

            logSummary(log, "Hungry filling finished, put payloads: %d/%d (%.1f%%). Loaded pages in PageMemory: %d",
                (l - 1), maxPagesNum, 100.0 * (l - 1) / maxPagesNum, pageMem.loadedPages());
        }
    }

    /**
     * Log summary message with formatted elements and show memory statistics.
     *
     * @param log         {@link IgniteLogger}, used to log messages
     * @param msg         Summary message
     * @param msgElements element print to
     */
    private void logSummary(IgniteLogger log, String msg, Object... msgElements) {
        log.warning(getClass().getSimpleName(), String.format(msg, msgElements), null);
        logMemUsage(log);
    }

    /**
     * Collect and log heap and OS memory information
     *
     * @param log {@link IgniteLogger}, used to log messages
     */
    private void logMemUsage(IgniteLogger log) {
        MemoryUsage heapUsage = ManagementFactory.getMemoryMXBean().getHeapMemoryUsage();
        long heapUsedMem = heapUsage.getUsed();
        long heapMaxMem = heapUsage.getMax();
        double heapUsagePercent = 100.0 * heapUsedMem / heapMaxMem;

        OperatingSystemMXBean osMXBean = (OperatingSystemMXBean)ManagementFactory.getOperatingSystemMXBean();
        long totalOsMem = osMXBean.getTotalPhysicalMemorySize();
        long usedOsMem = totalOsMem - osMXBean.getFreePhysicalMemorySize();
        double osMemUsagePercent = 100.0 * usedOsMem / totalOsMem;

        log.info(getClass().getSimpleName(),
            String.format("Heap usage: %d/%d (%.1f%%). OS memory usage: %d/%d (%.1f%%)",
                heapUsedMem, heapMaxMem, heapUsagePercent,
                usedOsMem, totalOsMem, osMemUsagePercent));
    }
}
