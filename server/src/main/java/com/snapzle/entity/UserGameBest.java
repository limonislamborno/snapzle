package com.snapzle.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.UpdateTimestamp;

import java.io.Serializable;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "user_game_bests", schema = "public")
@IdClass(UserGameBestId.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserGameBest {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Id
    @Column(name = "game_type", length = 20)
    private String gameType;

    @Column(name = "best_score", nullable = false)
    private Integer bestScore;

    @Column(name = "best_time_seconds", nullable = false)
    private Integer bestTimeSeconds;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
