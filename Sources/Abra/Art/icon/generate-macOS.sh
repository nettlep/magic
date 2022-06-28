#!/bin/bash

directory=AppIcon-macOS
sizes=(16 32 64 128 256 512)

if [[ -d ${directory} ]]; then
	echo "Deleting ${directory} directory"
	rm -rf ${directory}
fi

mkdir ${directory}

# Flatten it into a single 1024x1024
echo "Creating AppIcon-1024.png"
magick convert -alpha on -background none -layers flatten AppIcon-macOS.psd ${directory}/AppIcon-1024.png

# Generate sizes for each
for i in ${sizes[@]}; do
	echo "Creating AppIcon-$i.png"
	magick convert -resize $ix$i ${directory}/AppIcon-1024.png ${directory}/AppIcon-$i.png
done