package com.snapzle.repo;

import com.snapzle.entity.GameSession;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface GameSessionRepository extends JpaRepository<GameSession, UUID> {
    List<GameSession> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    @Query("SELECT gs FROM GameSession gs WHERE gs.gameType = :gameType AND gs.completed = true AND gs.verified = true ORDER BY gs.score DESC")
    List<GameSession> findTopScoresByGameType(@Param("gameType") String gameType, Pageable pageable);

    @Query("SELECT gs FROM GameSession gs WHERE gs.completed = true AND gs.verified = true AND gs.createdAt >= :since ORDER BY gs.score DESC")
    List<GameSession> findTopScoresSince(@Param("since") OffsetDateTime since, Pageable pageable);

    void deleteByUserId(UUID userId);
}
