package com.snapzle.controller;

import com.snapzle.repo.ProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicAuthController {

    private final ProfileRepository profileRepository;

    @GetMapping("/check-username")
    public ResponseEntity<Map<String, Boolean>> checkUsername(@RequestParam String username) {
        boolean exists = profileRepository.findByUsername(username.trim()).isPresent();
        return ResponseEntity.ok(Map.of("exists", exists));
    }
}
