package com.snapzle.dto;

import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LeaderboardEntryDto {
    private Integer rank;
    private UUID userId;
    private String username;
    private String avatarEmoji;
    private Integer avatarGradient;
    private Long points;
    private Integer level;
    private Integer gamesPlayed;
}
