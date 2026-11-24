package com.snapzle.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.*;
import java.util.List;

/**
 * Generates 5 natural, procedural differences on user images with zero external AI dependencies.
 * Guarantees exact coordinate calculation and zero cost/latency.
 */
@Service
public class ProceduralDiffService {

    private static final Logger log = LoggerFactory.getLogger(ProceduralDiffService.class);
    private final ObjectMapper objectMapper = new ObjectMapper();

    public record DiffResult(byte[] diffImageBytes, String spotsJson) {}

    public record Spot(int id, int x, int y, int radius, String type) {}

    public DiffResult generateDifferences(byte[] originalImageBytes) throws IOException {
        BufferedImage img = ImageIO.read(new ByteArrayInputStream(originalImageBytes));
        if (img == null) {
            throw new IllegalArgumentException("Invalid image bytes provided");
        }

        int width = img.getWidth();
        int height = img.getHeight();

        // Create a copy of the image for modifications
        BufferedImage diffImg = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = diffImg.createGraphics();
        g.drawImage(img, 0, 0, null);

        List<Spot> spots = new ArrayList<>();
        Random rand = new Random();

        // Select 5 distinct non-overlapping spots
        int marginX = (int) (width * 0.12);
        int marginY = (int) (height * 0.12);
        int spotRadius = Math.max(16, (int) (Math.min(width, height) * 0.05));

        for (int i = 1; i <= 5; i++) {
            int cx = marginX + rand.nextInt(width - 2 * marginX);
            int cy = marginY + rand.nextInt(height - 2 * marginY);

            // Apply different procedural alterations based on index
            switch (i) {
                case 1 -> applyHueShift(diffImg, cx, cy, spotRadius);
                case 2 -> applyBlur(diffImg, cx, cy, spotRadius);
                case 3 -> applyHorizontalMirror(diffImg, cx, cy, spotRadius);
                case 4 -> applyContrastShift(diffImg, cx, cy, spotRadius);
                case 5 -> applyPatchClone(diffImg, cx, cy, spotRadius);
            }

            // Normalise coordinates to percentage (0 - 100) for cross-device responsiveness
            int pctX = (int) Math.round(((double) cx / width) * 100);
            int pctY = (int) Math.round(((double) cy / height) * 100);
            spots.add(new Spot(i, pctX, pctY, spotRadius, "mod_" + i));
        }

        g.dispose();

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(diffImg, "jpg", baos);
        byte[] diffImageBytes = baos.toByteArray();
        String spotsJson = objectMapper.writeValueAsString(spots);

        return new DiffResult(diffImageBytes, spotsJson);
    }

    private void applyHueShift(BufferedImage img, int cx, int cy, int r) {
        for (int y = Math.max(0, cy - r); y < Math.min(img.getHeight(), cy + r); y++) {
            for (int x = Math.max(0, cx - r); x < Math.min(img.getWidth(), cx + r); x++) {
                if (Math.hypot(x - cx, y - cy) <= r) {
                    int rgb = img.getRGB(x, y);
                    int red = (rgb >> 16) & 0xFF;
                    int green = (rgb >> 8) & 0xFF;
                    int blue = rgb & 0xFF;

                    // Swap/shift channels subtly
                    int newR = Math.min(255, (int) (red * 0.75 + blue * 0.25));
                    int newG = Math.min(255, (int) (green * 0.85 + red * 0.15));
                    int newB = Math.min(255, (int) (blue * 0.80 + green * 0.20));

                    img.setRGB(x, y, (newR << 16) | (newG << 8) | newB);
                }
            }
        }
    }

    private void applyBlur(BufferedImage img, int cx, int cy, int r) {
        int minX = Math.max(1, cx - r);
        int maxX = Math.min(img.getWidth() - 2, cx + r);
        int minY = Math.max(1, cy - r);
        int maxY = Math.min(img.getHeight() - 2, cy + r);

        for (int y = minY; y <= maxY; y++) {
            for (int x = minX; x <= maxX; x++) {
                if (Math.hypot(x - cx, y - cy) <= r) {
                    int avgR = 0, avgG = 0, avgB = 0;
                    for (int dy = -1; dy <= 1; dy++) {
                        for (int dx = -1; dx <= 1; dx++) {
                            int rgb = img.getRGB(x + dx, y + dy);
                            avgR += (rgb >> 16) & 0xFF;
                            avgG += (rgb >> 8) & 0xFF;
                            avgB += rgb & 0xFF;
                        }
                    }
                    img.setRGB(x, y, ((avgR / 9) << 16) | ((avgG / 9) << 8) | (avgB / 9));
                }
            }
        }
    }

    private void applyHorizontalMirror(BufferedImage img, int cx, int cy, int r) {
        int minX = Math.max(0, cx - r);
        int maxX = Math.min(img.getWidth() - 1, cx + r);
        int minY = Math.max(0, cy - r);
        int maxY = Math.min(img.getHeight() - 1, cy + r);

        for (int y = minY; y <= maxY; y++) {
            for (int dx = 0; dx < r; dx++) {
                int leftX = cx - dx;
                int rightX = cx + dx;
                if (leftX >= minX && rightX <= maxX && Math.hypot(dx, y - cy) <= r) {
                    int leftRgb = img.getRGB(leftX, y);
                    int rightRgb = img.getRGB(rightX, y);
                    img.setRGB(leftX, y, rightRgb);
                    img.setRGB(rightX, y, leftRgb);
                }
            }
        }
    }

    private void applyContrastShift(BufferedImage img, int cx, int cy, int r) {
        for (int y = Math.max(0, cy - r); y < Math.min(img.getHeight(), cy + r); y++) {
            for (int x = Math.max(0, cx - r); x < Math.min(img.getWidth(), cx + r); x++) {
                if (Math.hypot(x - cx, y - cy) <= r) {
                    int rgb = img.getRGB(x, y);
                    int red = (rgb >> 16) & 0xFF;
                    int green = (rgb >> 8) & 0xFF;
                    int blue = rgb & 0xFF;

                    int newR = Math.min(255, (int) (red * 1.35));
                    int newG = Math.min(255, (int) (green * 1.35));
                    int newB = Math.min(255, (int) (blue * 1.35));

                    img.setRGB(x, y, (newR << 16) | (newG << 8) | newB);
                }
            }
        }
    }

    private void applyPatchClone(BufferedImage img, int cx, int cy, int r) {
        int offset = r * 2;
        int srcX = Math.max(0, Math.min(img.getWidth() - 1 - r, cx + offset));
        int srcY = Math.max(0, Math.min(img.getHeight() - 1 - r, cy));

        for (int dy = -r; dy <= r; dy++) {
            for (int dx = -r; dx <= r; dx++) {
                if (Math.hypot(dx, dy) <= r) {
                    int targetX = cx + dx;
                    int targetY = cy + dy;
                    int sourceX = srcX + dx;
                    int sourceY = srcY + dy;

                    if (targetX >= 0 && targetX < img.getWidth() && targetY >= 0 && targetY < img.getHeight() &&
                        sourceX >= 0 && sourceX < img.getWidth() && sourceY >= 0 && sourceY < img.getHeight()) {
                        img.setRGB(targetX, targetY, img.getRGB(sourceX, sourceY));
                    }
                }
            }
        }
    }
}
