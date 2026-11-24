package com.snapzle.dto;

import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProfileDto {
    private UUID id;
    private String username;
    private String avatarEmoji;
    private Integer avatarGradient;
    private Long points;
    private Integer level;
    private Integer xp;
    private Integer streak;
    private Integer gamesPlayed;
    private Boolean isPremium;
}
