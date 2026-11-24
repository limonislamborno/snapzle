package com.snapzle.dto;

import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameFinishResponse {
    private UUID sessionId;
    private Integer calculatedScore;
    private Integer basePoints;
    private Integer difficultyBonus;
    private Integer timeBonus;
    private Integer perfectBonus;
    private Boolean isNewPersonalBest;
    private Long totalUserPoints;
    private Integer userLevel;
    private Boolean verified;
}
