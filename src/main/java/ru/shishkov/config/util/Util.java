package ru.shishkov.config.util;

import com.sun.management.OperatingSystemMXBean;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import org.apache.ignite.cache.eviction.EvictionPolicy;
import org.apache.ignite.configuration.DataRegionConfiguration;

// TODO JavaDoc
// TODO available size should take into account NON-DEFAULT values of internal ignite variables (system and TxRegion, etc.)
public final class Util {

    /**
     * Estimate available memory for data region taking into account consumption of memory by internal Apache Ignite,
     * possible overheads and default value of eviction treshold.<br/>
     * <strong>NOTE:</strong> Return value is greater than free OS memory on 10/9 because of eviction treshhold.
     * It is made in order to correspond of really consumable volume to free OS memory. <br/>
     * <em>Now, only default values of eviction treshhold and other internal variables ate taken into account</em>
     *
     * @param osMxBean
     * @param memMxBean
     * @return
     * @see EvictionPolicy
     * @see DataRegionConfiguration
     */
    public static long availableMemoryForDataRegion(OperatingSystemMXBean osMxBean, MemoryMXBean memMxBean) {
        MemoryUsage heapMemUsage = memMxBean.getHeapMemoryUsage();
        long freeOsMem = osMxBean.getFreePhysicalMemorySize();

        // See max size of SysCache in DataStorageConfiguration#DFLT_SYS_REG_MAX_SIZE
        long DFLT_SYS_REG_MAX_SIZE = 100L * 1024 * 1024;

        //See DataRegionConfiguration#evictionThreshold
        double evictionThreshold = 0.9;

        // + additional TxLog region, see MvccProcessorImpl#createTxLogRegion max size equal to DFLT_SYS_REG_MAX_SIZE
        long availableMemory = Math.round((freeOsMem - heapMemUsage.getMax() - DFLT_SYS_REG_MAX_SIZE * 2) /
            evictionThreshold);

        if (availableMemory < 0)
            throw new IllegalStateException("Heap max size (Xmx) should be less than free OS memory to more than 200MB");

        return availableMemory;
    }

    /**
     * Get region size according to given properties and available memory for DataRegion.
     *
     * @param availMem available memory in OS
     * @param props    {@link GreedyProperties} containing nessesary system properties
     * @return
     * @throws IllegalArgumentException in case of incorrect properties passed via JVM arguments
     */
    public static long alternateDataRegionSize(long availMem, GreedyProperties props) {
        long retVal = -1;
        double eatRatio = props.getEatRatio();
        long overEatTotal = props.getOverEatSz() * 1024 * 1024 * 1024 + availMem;

        if (Double.isFinite(eatRatio) && eatRatio > 0.0)
            retVal = Math.round(eatRatio * availMem / 100.0);
        else if (overEatTotal >= availMem)
            retVal = overEatTotal;
        else if (props.getEatSz() <= 0)
            throw new IllegalArgumentException("'eat.ratio' property value should be correct positive double " +
                "or correct positive values for could be set 'eat.size' (in bytes) or 'over.eat.size' (in gigabytes");

        return retVal;
    }
}
