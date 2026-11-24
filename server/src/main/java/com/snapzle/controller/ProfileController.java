package com.snapzle.controller;

import com.snapzle.dto.ProfileDto;
import com.snapzle.service.ProfileService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    @GetMapping("/me")
    public ResponseEntity<ProfileDto> getMyProfile(@AuthenticationPrincipal UUID userId) {
        return ResponseEntity.ok(profileService.getProfile(userId));
    }

    @GetMapping("/user/{id}")
    public ResponseEntity<ProfileDto> getUserPublicProfile(@PathVariable UUID id) {
        return ResponseEntity.ok(profileService.getPublicProfile(id));
    }

    @PutMapping("/avatar")
    public ResponseEntity<ProfileDto> updateAvatar(
            @AuthenticationPrincipal UUID userId,
            @RequestBody Map<String, Object> body) {
        String emoji = (String) body.get("emoji");
        Integer gradient = body.get("gradient") != null ? ((Number) body.get("gradient")).intValue() : null;
        return ResponseEntity.ok(profileService.updateAvatar(userId, emoji, gradient));
    }

    @PostMapping("/daily-login")
    public ResponseEntity<Void> recordDailyLogin(@AuthenticationPrincipal UUID userId) {
        profileService.recordDailyLogin(userId);
        return ResponseEntity.ok().build();
    }
}
