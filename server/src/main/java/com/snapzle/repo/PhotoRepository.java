package com.snapzle.repo;

import com.snapzle.entity.Photo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PhotoRepository extends JpaRepository<Photo, UUID> {
    List<Photo> findByUserIdOrderByCreatedAtDesc(UUID userId);
    long countByUserId(UUID userId);
    void deleteByUserId(UUID userId);
}
