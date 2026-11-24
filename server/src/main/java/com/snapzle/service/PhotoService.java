package com.snapzle.service;

import com.snapzle.dto.PhotoDto;
import com.snapzle.entity.Photo;
import com.snapzle.repo.PhotoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PhotoService {

    private final PhotoRepository photoRepository;
    private final ProceduralDiffService proceduralDiffService;

    public List<PhotoDto> getUserPhotos(UUID userId) {
        return photoRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public PhotoDto savePhotoMetadata(UUID userId, String photoName, String storagePath, int fileSizeKb) {
        long currentCount = photoRepository.countByUserId(userId);
        if (currentCount >= 10) {
            throw new IllegalStateException("Maximum limit of 10 photos reached for free tier.");
        }

        Photo photo = Photo.builder()
                .userId(userId)
                .photoName(photoName)
                .storagePath(storagePath)
                .fileSizeKb(fileSizeKb)
                .diffSpots("[]")
                .build();

        return toDto(photoRepository.save(photo));
    }

    @Transactional
    public void deletePhoto(UUID userId, UUID photoId) {
        Photo photo = photoRepository.findById(photoId)
                .orElseThrow(() -> new IllegalArgumentException("Photo not found"));

        if (!photo.getUserId().equals(userId)) {
            throw new IllegalStateException("Unauthorized to delete this photo");
        }

        photoRepository.delete(photo);
    }

    private PhotoDto toDto(Photo p) {
        return PhotoDto.builder()
                .id(p.getId())
                .photoName(p.getPhotoName())
                .storagePath(p.getStoragePath())
                .diffStoragePath(p.getDiffStoragePath())
                .diffSpots(p.getDiffSpots())
                .fileSizeKb(p.getFileSizeKb())
                .createdAt(p.getCreatedAt())
                .build();
    }
}
