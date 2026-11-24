package com.snapzle.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "game_sessions", schema = "public")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameSession {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "game_type", nullable = false, length = 20)
    private String gameType; // 'puzzle', 'memory', 'diff', 'slide'

    @Column(name = "difficulty_level", nullable = false)
    private Integer difficultyLevel;

    @Column(name = "photo_id")
    private UUID photoId;

    @Column(name = "start_time", nullable = false)
    private OffsetDateTime startTime;

    @Column(name = "end_time")
    private OffsetDateTime endTime;

    @Column(name = "elapsed_seconds")
    private Integer elapsedSeconds;

    @Column(nullable = false)
    private Integer moves;

    @Column(nullable = false)
    private Integer score;

    @Column(name = "is_perfect", nullable = false)
    private Boolean isPerfect;

    @Column(nullable = false)
    private Boolean completed;

    @Column(nullable = false)
    private Boolean verified;

    @Column(name = "client_seed")
    private String clientSeed;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;
}
