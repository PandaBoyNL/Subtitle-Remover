#!/bin/bash
trap '' PIPE

SEARCH_DIR="${1:-/media}"
WEBHOOK_URL="${DISCORD_WEBHOOK}"

t_echo() {
    echo "[$(date +'%d-%m-%Y %H:%M:%S')] $1"
}

LANG_ENV="${LANG:-nl}"
if [[ "${LANG_ENV,,}" == *"nl"* ]]; then
    S_SEARCH="🔍 Zoeken naar mkv/mp4 video's in"
    S_FOUND="📁 Bestanden gevonden:"
    S_SCAN="👀 [SCAN]"
    S_MATCH="       -> 🎯 [MATCH] Ondertiteling gevonden! Starten met strippen ✂️..."
    S_SUCCES="       -> ✅ [SUCCES] Ondertiteling verwijderd. Bestand overschreven 🎬."
    S_FOUT="       -> ❌ [FOUT] Iets ging mis. Origineel blijft behouden."
    S_SKIP="       -> ⏭️ [SKIP] Geen ingebakken ondertiteling."
    S_KLAAR="🎉 Klaar met scannen en strippen!"
    S_DISCORD="✅ Het scannen en strippen in de map \`$SEARCH_DIR\` is succesvol afgerond!"
    S_UPDATE_TITLE="🎬 **SUB-GONE Voortgang** 🍿"
    S_UPDATE_MSG="⏳ **Update:** %d bestanden verwerkt. Nog %d te gaan!"
else
    S_SEARCH="🔍 Searching for mkv/mp4 videos in"
    S_FOUND="📁 Files found:"
    S_SCAN="👀 [SCAN]"
    S_MATCH="       -> 🎯 [MATCH] Subtitles found! Starting extraction ✂️..."
    S_SUCCES="       -> ✅ [SUCCESS] Subtitles removed. File overwritten 🎬."
    S_FOUT="       -> ❌ [ERROR] Something went wrong. Original kept."
    S_SKIP="       -> ⏭️ [SKIP] No hardcoded subtitles."
    S_KLAAR="🎉 Finished scanning and stripping!"
    S_DISCORD="✅ Scanning and stripping in folder \`$SEARCH_DIR\` completed successfully!"
    S_UPDATE_TITLE="🎬 **SUB-GONE Progress** 🍿"
    S_UPDATE_MSG="⏳ **Update:** %d files processed. %d left to go!"
fi

t_echo "$S_SEARCH$SEARCH_DIR..."
t_echo "---------------------------------------------------"

# Stap 1: Lees alle gevonden bestanden in één keer in een lijst (array)
mapfile -t files < <(find "$SEARCH_DIR" -type d \( -iname "Featurettes" -o -iname "Extras" -o -iname "Trailers" \) -prune -o -type f \( -iname "*.mkv" -o -iname "*.mp4" \) -print | sort)
TOTAL_FILES="${#files[@]}"

t_echo "$S_FOUND$TOTAL_FILES"
t_echo "---------------------------------------------------"

COUNT=0

# Stap 2: Loop door de lijst heen
for file in "${files[@]}"; do
    # Bij lege mappen skipt hij netjes
    [ -z "$file" ] && continue 

    ((COUNT++))
    t_echo "$S_SCAN [$COUNT/$TOTAL_FILES]$file"
    
    SUBS=$(ffprobe -loglevel fatal -probesize 100M -analyzeduration 100M -select_streams s -show_entries stream=index -of csv=p=0 "$file" 2>/dev/null)

    if [ -n "$SUBS" ]; then
        t_echo "$S_MATCH"
        temp_file="${file%.*}_temp.${file##*.}"

        ffmpeg -nostdin -probesize 100M -analyzeduration 100M -i "$file" -c copy -sn "$temp_file" -y -loglevel fatal 2>/dev/null

        if [ $? -eq 0 ]; then
            t_echo "$S_SUCCES"
            mv -f "$temp_file" "$file"
            chown 99:100 "$file" 2>/dev/null
            chmod 0666 "$file" 2>/dev/null
        else
            t_echo "$S_FOUT"
            rm -f "$temp_file"
        fi
    else
        t_echo "$S_SKIP"
    fi

    # Stap 3: Check of we op een honderdtal zitten (100, 200, 300, etc.)
    if (( COUNT % 100 == 0 )) && [ "$COUNT" -lt "$TOTAL_FILES" ]; then
        REMAINING=$((TOTAL_FILES - COUNT))
        
        if [ -n "$WEBHOOK_URL" ]; then
            # Format de tekst met de juiste nummers
            MSG=$(printf "$S_UPDATE_MSG" "$COUNT" "$REMAINING")
            
            curl -s -H "Content-Type: application/json" \
                 -X POST \
                 -d "{\"content\": \"$S_UPDATE_TITLE\n$MSG\"}" \
                 "$WEBHOOK_URL" > /dev/null
        fi
    fi
done

t_echo "---------------------------------------------------"
t_echo "$S_KLAAR"

if [ -n "$WEBHOOK_URL" ] && [ "$TOTAL_FILES" -gt 0 ]; then
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"🎬 **SUB-GONE** 🍿\n$S_DISCORD\"}" \
         "$WEBHOOK_URL" > /dev/null
fi
