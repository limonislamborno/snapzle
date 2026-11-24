package com.snapzle.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "profiles", schema = "public")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Profile {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @Column(name = "avatar_emoji", length = 10)
    private String avatarEmoji;

    @Column(name = "avatar_gradient")
    private Integer avatarGradient;

    @Column(nullable = false)
    private Long points;

    @Column(nullable = false)
    private Integer level;

    @Column(nullable = false)
    private Integer xp;

    @Column(nullable = false)
    private Integer streak;

    @Column(name = "last_login_date")
    private LocalDate lastLoginDate;

    @Column(name = "games_played", nullable = false)
    private Integer gamesPlayed;

    @Column(name = "is_premium", nullable = false)
    private Boolean isPremium;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
