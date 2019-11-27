package ru.shishkov;

import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import ru.shishkov.config.ClientConfig;
import ru.shishkov.config.ServerConfig;
import ru.shishkov.config.util.HungryJob;

/**
 * Utility is developed to check Apache Ignite behaviour when it uses memory more than operating system has. It's
 * purpose to fill as more space as it is permitted by a given configuration
 */
public class GreedyIgnite {
    private static ApplicationContext ctx;

    // TODO Lazy filling
    // TODO Help message
    public static void main(String[] args) {
        ApplicationContext ctx = init();

        HungryJob hungryJob = (HungryJob)ctx.getBean("hungryJob");
        hungryJob.performJob();

//        switch (args[0]) {
//            case "lazy-test":
//                eatSpace(true);
//                break;
//            case "hungry-test":
//                eatSpace(false);
//                break;
//            default:
//                System.err.println("Error in command-line arguments. Usage:\n" +
//                    "greedy-ignite.jar {lazy-test|hungry-test}\n\n" +
//                    "NOTE: Extra-values can be set via JVM parameters:\n" +
//                    "'eat.size' - size (long) of Ignite's default data region, wich will be consumed, defailt - zero\n" +
//                    "'eat.ratio' - percents (double) of free OS memory which will be consumed, " +
//                    "ignored if 'eat.size' is set, default - 50.0\n" +
//                    "'percistence' - set true to turn on percistence (boolean), " +
//                    "BE CAREFUL and check for available disk size, default - false");
//        }
    }

    private static ApplicationContext init() {
        Thread.currentThread().setName(GreedyIgnite.class.getSimpleName());

        boolean isClientMode = Boolean.parseBoolean(System.getProperty("client.mode", "false"));

        ctx = isClientMode ? new AnnotationConfigApplicationContext(ClientConfig.class) :
            new AnnotationConfigApplicationContext(ServerConfig.class);

        return ctx;
    }
}
