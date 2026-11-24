package com.snapzle.dto;

import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameFinishRequest {
    @NotNull
    private UUID sessionId;

    @NotNull
    private Integer moves;

    @NotNull
    private Integer elapsedSeconds;

    private Boolean isPerfect;
    private String completionProof;
}
