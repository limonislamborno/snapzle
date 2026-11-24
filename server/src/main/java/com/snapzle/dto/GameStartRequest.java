package com.snapzle.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameStartRequest {
    @NotBlank
    private String gameType; // 'puzzle', 'memory', 'diff', 'slide'

    @NotNull
    private Integer difficultyLevel;

    private UUID photoId;
}
