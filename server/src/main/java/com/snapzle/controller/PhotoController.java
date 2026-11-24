package com.snapzle.controller;

import com.snapzle.dto.PhotoDto;
import com.snapzle.service.PhotoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/photos")
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService photoService;

    @GetMapping
    public ResponseEntity<List<PhotoDto>> getMyPhotos(@AuthenticationPrincipal UUID userId) {
        return ResponseEntity.ok(photoService.getUserPhotos(userId));
    }

    @PostMapping("/metadata")
    public ResponseEntity<PhotoDto> savePhotoMetadata(
            @AuthenticationPrincipal UUID userId,
            @RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        String path = (String) body.get("storagePath");
        int sizeKb = body.get("sizeKb") != null ? ((Number) body.get("sizeKb")).intValue() : 0;
        return ResponseEntity.ok(photoService.savePhotoMetadata(userId, name, path, sizeKb));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePhoto(
            @AuthenticationPrincipal UUID userId,
            @PathVariable UUID id) {
        photoService.deletePhoto(userId, id);
        return ResponseEntity.noContent().build();
    }
}
