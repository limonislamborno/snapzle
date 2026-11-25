package com.snapzle.repo;

import com.snapzle.entity.UserGameBest;
import com.snapzle.entity.UserGameBestId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserGameBestRepository extends JpaRepository<UserGameBest, UserGameBestId> {
    List<UserGameBest> findByUserId(UUID userId);
    Optional<UserGameBest> findByUserIdAndGameType(UUID userId, String gameType);
    void deleteByUserId(UUID userId);
}
