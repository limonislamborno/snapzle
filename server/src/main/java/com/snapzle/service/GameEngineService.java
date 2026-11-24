package com.snapzle.service;

import com.snapzle.dto.GameFinishRequest;
import com.snapzle.dto.GameFinishResponse;
import com.snapzle.dto.GameStartRequest;
import com.snapzle.dto.GameStartResponse;
import com.snapzle.entity.GameSession;
import com.snapzle.entity.Profile;
import com.snapzle.entity.UserGameBest;
import com.snapzle.repo.GameSessionRepository;
import com.snapzle.repo.ProfileRepository;
import com.snapzle.repo.UserGameBestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class GameEngineService {

    private final GameSessionRepository gameSessionRepository;
    private final ProfileRepository profileRepository;
    private final UserGameBestRepository userGameBestRepository;

    private static final Map<String, int[]> BASE_POINTS = Map.of(
            "puzzle", new int[]{300, 600, 1000},
            "memory", new int[]{250, 500, 800},
            "diff", new int[]{300, 550, 900},
            "slide", new int[]{350, 800}
    );

    @Transactional
    public GameStartResponse startGame(UUID userId, GameStartRequest request) {
        String clientSeed = UUID.randomUUID().toString().substring(0, 8);

        GameSession session = GameSession.builder()
                .userId(userId)
                .gameType(request.getGameType())
                .difficultyLevel(request.getDifficultyLevel())
                .photoId(request.getPhotoId())
                .startTime(OffsetDateTime.now())
                .moves(0)
                .score(0)
                .isPerfect(false)
                .completed(false)
                .verified(false)
                .clientSeed(clientSeed)
                .build();

        GameSession saved = gameSessionRepository.save(session);

        return GameStartResponse.builder()
                .sessionId(saved.getId())
                .gameType(saved.getGameType())
                .difficultyLevel(saved.getDifficultyLevel())
                .clientSeed(clientSeed)
                .startTime(saved.getStartTime())
                .build();
    }

    @Transactional
    public GameFinishResponse finishGame(UUID userId, GameFinishRequest request) {
        GameSession session = gameSessionRepository.findById(request.getSessionId())
                .orElseThrow(() -> new IllegalArgumentException("Game session not found"));

        if (!session.getUserId().equals(userId)) {
            throw new IllegalStateException("Unauthorized game session access");
        }

        if (session.getCompleted()) {
            throw new IllegalStateException("Game session is already finished");
        }

        // Anti-Cheat: Minimum realistic time and move limits
        boolean verified = validateAntiCheat(session.getGameType(), session.getDifficultyLevel(),
                request.getElapsedSeconds(), request.getMoves());

        // Calculate score breakdown
        int[] bases = BASE_POINTS.getOrDefault(session.getGameType(), new int[]{300, 500, 800});
        int levelIdx = Math.min(session.getDifficultyLevel(), bases.length - 1);
        int base = bases[levelIdx];

        int diffBonus = levelIdx == 1 ? (int) (base * 0.10) : (levelIdx >= 2 ? (int) (base * 0.25) : 0);
        int timeBonus = Math.max(0, 400 - (request.getElapsedSeconds() * 2));
        int perfectBonus = Boolean.TRUE.equals(request.getIsPerfect()) ? 150 : 0;
        int totalScore = verified ? (base + diffBonus + timeBonus + perfectBonus) : 0;

        session.setEndTime(OffsetDateTime.now());
        session.setElapsedSeconds(request.getElapsedSeconds());
        session.setMoves(request.getMoves());
        session.setScore(totalScore);
        session.setIsPerfect(Boolean.TRUE.equals(request.getIsPerfect()));
        session.setCompleted(true);
        session.setVerified(verified);
        gameSessionRepository.save(session);

        // Update User Profile & Best Scores if verified
        boolean isNewBest = false;
        Profile profile = profileRepository.findById(userId).orElseThrow();

        if (verified) {
            profile.setPoints(profile.getPoints() + totalScore);
            profile.setGamesPlayed(profile.getGamesPlayed() + 1);
            profile.setXp(profile.getXp() + totalScore / 2);

            // Level up threshold: level * 1000
            int nextLevelXp = profile.getLevel() * 1000;
            if (profile.getXp() >= nextLevelXp) {
                profile.setLevel(profile.getLevel() + 1);
                profile.setXp(profile.getXp() - nextLevelXp);
            }
            profileRepository.save(profile);

            // Update user best
            UserGameBest best = userGameBestRepository.findByUserIdAndGameType(userId, session.getGameType())
                    .orElse(UserGameBest.builder()
                            .userId(userId)
                            .gameType(session.getGameType())
                            .bestScore(0)
                            .bestTimeSeconds(999999)
                            .build());

            if (totalScore > best.getBestScore()) {
                best.setBestScore(totalScore);
                best.setBestTimeSeconds(request.getElapsedSeconds());
                userGameBestRepository.save(best);
                isNewBest = true;
            }
        }

        return GameFinishResponse.builder()
                .sessionId(session.getId())
                .calculatedScore(totalScore)
                .basePoints(base)
                .difficultyBonus(diffBonus)
                .timeBonus(timeBonus)
                .perfectBonus(perfectBonus)
                .isNewPersonalBest(isNewBest)
                .totalUserPoints(profile.getPoints())
                .userLevel(profile.getLevel())
                .verified(verified)
                .build();
    }

    private boolean validateAntiCheat(String gameType, int difficulty, int elapsedSeconds, int moves) {
        // Impossible completion time checks
        if (elapsedSeconds < 3) return false;

        return switch (gameType) {
            case "puzzle" -> moves >= (difficulty == 0 ? 5 : (difficulty == 1 ? 10 : 18));
            case "memory" -> moves >= (difficulty == 0 ? 6 : (difficulty == 1 ? 8 : 10)) && elapsedSeconds >= 5;
            case "diff" -> moves >= 5 && elapsedSeconds >= 4;
            case "slide" -> moves >= (difficulty == 0 ? 8 : 15) && elapsedSeconds >= 4;
            default -> true;
        };
    }
}
