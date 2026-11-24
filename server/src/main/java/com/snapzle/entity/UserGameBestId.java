package com.snapzle.entity;

import lombok.*;
import java.io.Serializable;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode
public class UserGameBestId implements Serializable {
    private UUID userId;
    private String gameType;
}
