package ru.shishkov.config.util;

import com.sun.management.OperatingSystemMXBean;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;

public final class Utilz {
    public static long availableMemory(OperatingSystemMXBean osMxBean, MemoryMXBean memMxBean) {
        MemoryUsage heapMemUsage = memMxBean.getHeapMemoryUsage();
        long freeOsMem = osMxBean.getFreePhysicalMemorySize();

        // See max size of SysCache in DataStorageConfiguration#DFLT_SYS_REG_MAX_SIZE
        long DFLT_SYS_REG_MAX_SIZE = 100L * 1024 * 1024;

        // + additional TxLog region, see MvccProcessorImpl#createTxLogRegion max size equal to DFLT_SYS_REG_MAX_SIZE
        long availableMemory = freeOsMem - heapMemUsage.getMax() - DFLT_SYS_REG_MAX_SIZE * 2;

        if (availableMemory < 0)
            throw new IllegalStateException("Heap max size (Xmx) should be less than free OS memory to more than 200MB");

        return availableMemory;
    }

    public static long estimateDataRegionSize(long availMem, double eatRatio, long eatSize) {
        if (eatSize > 0) {
            return eatSize;
        }
        else {
            if (eatRatio > 0.0 && Double.isFinite(eatRatio))
                return Math.round(eatRatio * availMem / 100.0);
            else
                throw new IllegalArgumentException("'eat.ratio' property value should be correct positive double");
        }
    }
}
