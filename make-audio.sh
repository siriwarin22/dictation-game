#!/bin/bash
# Records every word in words.tsv with the Mac's built-in voices and zips them
# for the game, so words play the same on every browser (Brave included).
# Run on a Mac:
#   curl -fsSL https://raw.githubusercontent.com/siriwarin22/dictation-game/main/make-audio.sh | bash
set -euo pipefail

# clearest voice installed wins; download better ones in System Settings → Accessibility →
# Spoken Content → System voice → Manage Voices (Thai: Narisa / Kanya "Premium" or "Enhanced")
pick(){ for v in "$@"; do grep -q "^$v  *[a-z][a-z]_" <<<"$VOICES" && { echo "$v"; return 0; }; done; return 0; }
RATE="${RATE:-150}"
WORK="$HOME/Desktop/dictation-audio"
LIST_URL="https://raw.githubusercontent.com/siriwarin22/dictation-game/main/words.tsv"

if ! command -v say >/dev/null; then echo "ต้องรันบน Mac เท่านั้น"; exit 1; fi
VOICES="$(say -v '?')"
TH_VOICE="${TH_VOICE:-$(pick "Narisa (Premium)" "Kanya (Premium)" "Narisa (Enhanced)" "Kanya (Enhanced)" "Narisa" "Kanya")}"
EN_VOICE="${EN_VOICE:-$(pick "Ava (Premium)" "Zoe (Premium)" "Samantha (Enhanced)" "Ava (Enhanced)" "Allison (Enhanced)" "Samantha")}"
echo "เสียงไทย: ${TH_VOICE:-ไม่พบ}   เสียงอังกฤษ: ${EN_VOICE:-ไม่พบ}"
has_voice(){ [ -n "$1" ] && grep -q "^$1 " <<<"$VOICES"; }
if ! has_voice "$TH_VOICE"; then
  echo "ไม่พบเสียงภาษาไทยในเครื่อง"
  echo "เพิ่มได้ที่ System Settings → Accessibility → Spoken Content → System voice → Manage Voices → Thai"
  exit 1
fi
has_voice "$EN_VOICE" || { echo "ไม่พบเสียง \"$EN_VOICE\" จะใช้เสียงอังกฤษเริ่มต้นแทน"; EN_VOICE=""; }

rm -rf "$WORK"; mkdir -p "$WORK/audio"
curl -fsSL "$LIST_URL" -o "$WORK/words.tsv"
total=$(wc -l < "$WORK/words.tsv" | tr -d ' ')
n=0; ids=()
while IFS=$'\t' read -r id lang word; do
  [ -z "$id" ] && continue
  n=$((n+1)); printf "\rกำลังอัดเสียง %d/%d  %s                    " "$n" "$total" "$word"
  if [ "$lang" = "th" ]; then v="$TH_VOICE"; else v="$EN_VOICE"; fi
  if [ -n "$v" ]; then say -v "$v" -r "$RATE" -o "$WORK/audio/$id.m4a" --file-format=m4af --data-format=aac "$word"
  else say -r "$RATE" -o "$WORK/audio/$id.m4a" --file-format=m4af --data-format=aac "$word"; fi
  ids+=("\"$id\"")
done < "$WORK/words.tsv"
( IFS=,; echo "{\"voice\":{\"th\":\"$TH_VOICE\",\"en\":\"${EN_VOICE:-default}\"},\"ids\":[${ids[*]}]}" ) > "$WORK/audio/manifest.json"
cd "$WORK" && rm -f ../dictation-audio.zip && zip -qr ../dictation-audio.zip audio
echo
echo "เสร็จแล้ว: ไฟล์ dictation-audio.zip อยู่บน Desktop ($n คำ)"
echo "ส่งไฟล์นี้ให้ Claude ในแชตได้เลย"
