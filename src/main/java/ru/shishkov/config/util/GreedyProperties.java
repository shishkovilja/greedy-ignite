package ru.shishkov.config.util;

import org.springframework.beans.factory.annotation.Value;

public class GreedyProperties {
    @Value("${eat.ratio:0.0}")
    private Double eatRatio;

    @Value("${eat.size:0}")
    private Long eatSz;

    @Value("${laziness:0.0}")
    private Double laziness;

    @Value("${over.eat.size:-1}")
    private Long overEatSz;

    @Value("${stomach.cache:stomach}")
    private String stomachCacheName;

    @Value("${subtotals.percent:10.0}")
    private Double subtotalsPercent;

    public Double getEatRatio() {
        return eatRatio;
    }

    public void setEatRatio(Double eatRatio) {
        this.eatRatio = eatRatio;
    }

    public Long getEatSz() {
        return eatSz;
    }

    public void setEatSz(Long eatSz) {
        this.eatSz = eatSz;
    }

    public Double getLaziness() {
        return laziness;
    }

    public void setLaziness(Double laziness) {
        this.laziness = laziness;
    }

    public Long getOverEatSz() {
        return overEatSz;
    }

    public void setOverEatSz(Long overEatSz) {
        this.overEatSz = overEatSz;
    }

    public String getStomachCacheName() {
        return stomachCacheName;
    }

    public void setStomachCacheName(String stomachCacheName) {
        this.stomachCacheName = stomachCacheName;
    }

    public Double getSubtotalsPercent() {
        return subtotalsPercent;
    }

    public void setSubtotalsPercent(Double subtotalsPercent) {
        this.subtotalsPercent = subtotalsPercent;
    }

    @Override
    public String toString() {
        return "GreedyProperties{" +
                "eatRatio=" + eatRatio +
                ", eatSz=" + eatSz +
                ", laziness=" + laziness +
                ", overEatSz=" + overEatSz +
                ", stomachCacheName='" + stomachCacheName + '\'' +
                ", subtotalsPercent=" + subtotalsPercent +
                '}';
    }
}
