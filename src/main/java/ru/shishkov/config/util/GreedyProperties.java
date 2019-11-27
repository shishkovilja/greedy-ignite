package ru.shishkov.config.util;

import org.springframework.beans.factory.annotation.Value;

public class GreedyProperties {
    @Value("${eat.ratio:50.0}")
    private Double eatRatioProp;

    @Value("${eat.size:0}")
    private Long eatSizeProp;

    @Value("${eat.lazy:false}")
    private Boolean isEatLazy;

    @Value("${stomach.cache:stomach}")
    private String stomachCacheName;

    @Value("${subtotals.percent:1.0}")
    private Double subtotalsPercent;

    public Double getEatRatioProp() {
        return eatRatioProp;
    }

    public void setEatRatioProp(Double eatRatioProp) {
        this.eatRatioProp = eatRatioProp;
    }

    public Long getEatSizeProp() {
        return eatSizeProp;
    }

    public void setEatSizeProp(Long eatSizeProp) {
        this.eatSizeProp = eatSizeProp;
    }

    public Boolean getEatLazy() {
        return isEatLazy;
    }

    public void setEatLazy(Boolean eatLazy) {
        isEatLazy = eatLazy;
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

    @Override public String toString() {
        return "GreedyProperties{" +
            "eatRatioProp=" + eatRatioProp +
            ", eatSizeProp=" + eatSizeProp +
            ", isEatLazy=" + isEatLazy +
            ", stomachCacheName='" + stomachCacheName + '\'' +
            ", subtotalsPercent=" + subtotalsPercent +
            '}';
    }
}
