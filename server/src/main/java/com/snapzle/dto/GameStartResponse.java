package com.snapzle.dto;

import lombok.*;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameStartResponse {
    private UUID sessionId;
    private String gameType;
    private Integer difficultyLevel;
    private String clientSeed;
    private OffsetDateTime startTime;
}
