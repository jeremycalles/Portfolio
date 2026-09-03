const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const projectRoot = path.resolve(__dirname, '../../');
const appIconSetPath = path.join(projectRoot, 'Shared/Assets.xcassets/AppIcon.appiconset');
const contentsJsonPath = path.join(appIconSetPath, 'Contents.json');
// Source of truth for every AppIcon PNG. Contents.json only lists those PNGs —
// a loose icon.svg in the appiconset is ignored by the asset compiler.
const sourceIconPath = path.join(projectRoot, 'assets/app-icon-source.jpg');

async function generateIcons() {
    try {
        if (!fs.existsSync(sourceIconPath)) {
            console.error('Source icon not found:', sourceIconPath);
            process.exit(1);
        }

        const contents = JSON.parse(fs.readFileSync(contentsJsonPath, 'utf8'));
        const images = contents.images;

        console.log(`Found ${images.length} images to generate...`);

        for (const image of images) {
            const sizeStr = image.size; // e.g., "20x20"
            const scaleStr = image.scale; // e.g., "2x"
            const filename = image.filename;

            if (!filename) continue;

            const sizeParts = sizeStr.split('x');
            const baseSize = parseFloat(sizeParts[0]);
            const scale = parseFloat(scaleStr.replace('x', ''));
            const pixelSize = Math.round(baseSize * scale);

            console.log(`Generating ${filename} (${pixelSize}x${pixelSize})...`);

            // Opaque RGB (App Store rejects iOS icons with alpha). Flatten to black
            // so the dark gold-chart artwork does not pick up a white halo.
            await sharp(sourceIconPath)
                .resize(pixelSize, pixelSize, { fit: 'cover' })
                .flatten({ background: '#000000' })
                .removeAlpha()
                .png()
                .toFile(path.join(appIconSetPath, filename));
        }

        console.log('All icons generated successfully.');

    } catch (error) {
        console.error('Error generating icons:', error);
        process.exit(1);
    }
}

generateIcons();
