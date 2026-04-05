#!/bin/bash

CACHES=(
    "~/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage/*"
    "~/Library/Application Support/Microsoft/Teams/Service Worker/CacheStorage/*"
    "~/Library/Caches/*"
    "~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/*"
    "~/Library/Developer/CoreSimulator/Caches/*"
    "~/.cache/*"
    "~/Library/Application Support/Adobe/Common/Media Cache Files/*"
    "~/Library/Application Support/Adobe/Common/Media Cache/*"
    "~/Library/Application Support/Adobe/Common/PTK/*"
    "~/Library/Application Support/Adobe/Common/Peak Files/*"
    "~/Library/Developer/Xcode/DerivedData/*"
    "~/Library/Application Support/Spotify/PersistentCache/*" 
    "~/Library/Logs/*"
    "~/Library/Application Support/Code/CachedExtensionVSIXs/*"
    "~/.gradle/caches/*"
    "~/Library/Developer/Xcode/iOS DeviceSupport/*"
    "~/Library/Developer/CoreSimulator/Devices/*"
    "~/.android/avd/*"
    
    "/Library/Application Support/Adobe/CameraRaw/GPUCache/*"
    "/Library/Application Support/Adobe/CameraRaw/Cache/*"
)

BEFORE=$(df -m / | awk 'NR==2 {print $4}')

echo "--- Starting Universal Cache Cleanup ---"
echo "Running as user: $USER"

for folder in "${CACHES[@]}"; do
    expanded_folder=$(eval echo "$folder")
    
    if [ -d "$expanded_folder" ]; then
        echo "Cleaning: $expanded_folder"
        rm -rf "$expanded_folder"/* 2>/dev/null
    else
        echo "Skipping: $expanded_folder (Not found)"
    fi
done

sleep 2
AFTER=$(df -m / | awk 'NR==2 {print $4}')
RECOVERED=$((AFTER - BEFORE))

echo "--------------------------------"
echo "Cleanup Complete!"
echo "Space Recovered: ${RECOVERED} MB"
echo "Available Space: $(df -h / | awk 'NR==2 {print $4}')"
echo "--------------------------------"