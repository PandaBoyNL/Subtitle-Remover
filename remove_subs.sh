#!/bin/bash
trap '' PIPE

SEARCH_DIR="${1:-/media}"
WEBHOOK_URL="https://discord.com/api/webhooks/1554689534187274270/M-APr2bS8wpctXLd4H1Y8SKdq6JjMpdIU4d2MKqyB0Yr5EHpFrRyd3Pt8BDUaGzoz81h"

echo "🔍 Zoeken naar mkv/mp4 video's in $SEARCH_DIR..."
echo "---------------------------------------------------"

find "$SEARCH_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" \) | while read -r file; do
    echo "👀 [SCAN] Controleer: $file"
    
    SUBS=$(ffprobe -loglevel error -probesize 100M -analyzeduration 100M -select_streams s -show_entries stream=index -of csv=p=0 "$file")

    if [ -n "$SUBS" ]; then
        echo "       -> 🎯 [MATCH] Ondertiteling gevonden! Starten met strippen ✂️..."
        temp_file="${file\%.*}_temp.${file##*.}"

        ffmpeg -nostdin -probesize 100M -analyzeduration 100M -i "$file" -c copy -sn "$temp_file" -y -loglevel error

        if [ $? -eq 0 ]; then
            echo "       -> ✅ [SUCCES] Ondertiteling verwijderd. Bestand overschreven 🎬."
            mv -f "$temp_file" "$file"
            chown 99:100 "$file" 2>/dev/null
            chmod 0666 "$file" 2>/dev/null
        else
            echo "       -> ❌ [FOUT] Iets ging mis. Origineel blijft behouden."
            rm -f "$temp_file"
        fi
    else
        echo "       -> ⏭️ [SKIP] Geen ingebakken ondertiteling."
    fi
done

echo "---------------------------------------------------"
echo "🎉 Klaar met scannen en strippen!"

if [ "$WEBHOOK_URL" != "VUL_HIER_JE_WEBHOOK_URL_IN" ] && [ -n "$WEBHOOK_URL" ]; then
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"🎬 **SUB-GONE** 🍿\n✅ Het scannen en strippen in de map \`$SEARCH_DIR\` is succesvol afgerond!\"}" \
         "$WEBHOOK_URL" > /dev/null
fi
