package com.snapzle.dto;

import lombok.*;

import java.time.OffsetDateTime;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PhotoDto {
    private UUID id;
    private String photoName;
    private String storagePath;
    private String diffStoragePath;
    private String diffSpots;
    private Integer fileSizeKb;
    private OffsetDateTime createdAt;
}
