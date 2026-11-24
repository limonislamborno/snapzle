package com.snapzle.service;

import com.snapzle.dto.LeaderboardEntryDto;
import com.snapzle.entity.Profile;
import com.snapzle.repo.ProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class LeaderboardService {

    private final ProfileRepository profileRepository;

    public List<LeaderboardEntryDto> getGlobalLeaderboard(int limit) {
        List<Profile> topProfiles = profileRepository.findTopProfiles(PageRequest.of(0, Math.min(limit, 100)));
        List<LeaderboardEntryDto> entries = new ArrayList<>();

        for (int i = 0; i < topProfiles.size(); i++) {
            Profile p = topProfiles.get(i);
            entries.add(LeaderboardEntryDto.builder()
                    .rank(i + 1)
                    .userId(p.getId())
                    .username(p.getUsername())
                    .avatarEmoji(p.getAvatarEmoji())
                    .avatarGradient(p.getAvatarGradient())
                    .points(p.getPoints())
                    .level(p.getLevel())
                    .gamesPlayed(p.getGamesPlayed())
                    .build());
        }

        return entries;
    }
}
