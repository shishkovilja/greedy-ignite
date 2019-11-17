package ru.shishkov;

import com.sun.management.OperatingSystemMXBean;
import org.apache.ignite.Ignite;
import org.apache.ignite.IgniteCache;
import org.apache.ignite.IgniteDataStreamer;
import org.apache.ignite.Ignition;
import org.apache.ignite.configuration.DataStorageConfiguration;
import org.apache.ignite.configuration.IgniteConfiguration;

import java.lang.management.ManagementFactory;

public class IgniteMemoryOvercommitTest {
    public static void main(String[] args) {
        Ignite ignite = startIgnite();

        startEagerEating(ignite);
    }

    private static void startEagerEating(Ignite ignite) {
        String cacheName = "stomach";
        int entitySz = 3800;

        IgniteCache<Long, byte[]> cache = ignite.getOrCreateCache(cacheName);

        try (IgniteDataStreamer<Long, byte[]> streamer = ignite.dataStreamer(cacheName)) {
            for (long l = 0; l < Long.MAX_VALUE; l++) {
                streamer.addData(l, new byte[entitySz]);
            }
        }
    }

    private static Ignite startIgnite() {
        OperatingSystemMXBean osMXBean = (OperatingSystemMXBean) ManagementFactory.getOperatingSystemMXBean();
        long freeMem = osMXBean.getFreePhysicalMemorySize() * 2;

        DataStorageConfiguration dsCfg = new DataStorageConfiguration();
        dsCfg.getDefaultDataRegionConfiguration().setMaxSize(freeMem);
        IgniteConfiguration cfg = new IgniteConfiguration().setDataStorageConfiguration(dsCfg);

        return Ignition.start(cfg);
    }
}
