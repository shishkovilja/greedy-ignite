package ru.shishkov;

import org.apache.ignite.Ignite;
import org.apache.ignite.IgniteCache;
import org.apache.ignite.IgniteDataStreamer;
import org.apache.ignite.Ignition;
import org.apache.ignite.configuration.DataStorageConfiguration;
import org.apache.ignite.configuration.IgniteConfiguration;

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
        long freeMem = Runtime.getRuntime().freeMemory();

        DataStorageConfiguration dsCfg = new DataStorageConfiguration();
        dsCfg.getDefaultDataRegionConfiguration().setMaxSize(freeMem);
        IgniteConfiguration cfg = new IgniteConfiguration().setDataStorageConfiguration(dsCfg);

        return Ignition.start(cfg);
    }

    private static long getFreeMemory() {
        return Runtime.getRuntime().freeMemory();
    }
}
