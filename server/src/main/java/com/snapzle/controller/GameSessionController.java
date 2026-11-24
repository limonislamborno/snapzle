package com.snapzle.controller;

import com.snapzle.dto.GameFinishRequest;
import com.snapzle.dto.GameFinishResponse;
import com.snapzle.dto.GameStartRequest;
import com.snapzle.dto.GameStartResponse;
import com.snapzle.service.GameEngineService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/games")
@RequiredArgsConstructor
public class GameSessionController {

    private final GameEngineService gameEngineService;

    @PostMapping("/start")
    public ResponseEntity<GameStartResponse> startGame(
            @AuthenticationPrincipal UUID userId,
            @Valid @RequestBody GameStartRequest request) {
        return ResponseEntity.ok(gameEngineService.startGame(userId, request));
    }

    @PostMapping("/finish")
    public ResponseEntity<GameFinishResponse> finishGame(
            @AuthenticationPrincipal UUID userId,
            @Valid @RequestBody GameFinishRequest request) {
        return ResponseEntity.ok(gameEngineService.finishGame(userId, request));
    }
}
