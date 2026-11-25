package com.snapzle.service;

import com.snapzle.dto.ProfileDto;
import com.snapzle.entity.Profile;
import com.snapzle.repo.GameSessionRepository;
import com.snapzle.repo.PhotoRepository;
import com.snapzle.repo.ProfileRepository;
import com.snapzle.repo.UserGameBestRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ProfileService {

    private final ProfileRepository profileRepository;
    private final PhotoRepository photoRepository;
    private final GameSessionRepository gameSessionRepository;
    private final UserGameBestRepository userGameBestRepository;

    public ProfileDto getProfile(UUID userId) {
        Profile profile = profileRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Profile not found"));
        return toDto(profile);
    }

    public ProfileDto getPublicProfile(UUID userId) {
        return getProfile(userId);
    }

    @Transactional
    public ProfileDto updateAvatar(UUID userId, String emoji, Integer gradient) {
        Profile profile = profileRepository.findById(userId).orElseThrow();
        if (emoji != null) profile.setAvatarEmoji(emoji);
        if (gradient != null) profile.setAvatarGradient(gradient);
        return toDto(profileRepository.save(profile));
    }

    @Transactional
    public void recordDailyLogin(UUID userId) {
        Profile profile = profileRepository.findById(userId).orElseThrow();
        LocalDate today = LocalDate.now();

        if (profile.getLastLoginDate() == null) {
            profile.setStreak(1);
        } else if (profile.getLastLoginDate().plusDays(1).isEqual(today)) {
            profile.setStreak(profile.getStreak() + 1);
        } else if (!profile.getLastLoginDate().isEqual(today)) {
            profile.setStreak(1);
        }

        profile.setLastLoginDate(today);
        profileRepository.save(profile);
    }

    @Transactional
    public void deleteAccount(UUID userId) {
        photoRepository.deleteByUserId(userId);
        gameSessionRepository.deleteByUserId(userId);
        userGameBestRepository.deleteByUserId(userId);
        profileRepository.deleteById(userId);
    }

    private ProfileDto toDto(Profile p) {
        return ProfileDto.builder()
                .id(p.getId())
                .username(p.getUsername())
                .avatarEmoji(p.getAvatarEmoji())
                .avatarGradient(p.getAvatarGradient())
                .points(p.getPoints())
                .level(p.getLevel())
                .xp(p.getXp())
                .streak(p.getStreak())
                .gamesPlayed(p.getGamesPlayed())
                .isPremium(p.getIsPremium())
                .build();
    }
}
