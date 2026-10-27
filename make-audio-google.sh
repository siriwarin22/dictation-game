#!/bin/bash
# Records every word in words.tsv with Google Cloud Text-to-Speech and zips the
# files for the game (same output as make-audio.sh, Google voices instead of Mac ones).
# Needs a Google Cloud API key with the Text-to-Speech API enabled. Run on a Mac:
#   GOOGLE_TTS_KEY=your-key bash -c "$(curl -fsSL https://raw.githubusercontent.com/siriwarin22/dictation-game/main/make-audio-google.sh)"
# The key stays on this Mac; it is never written to the zip.
set -euo pipefail

KEY="${GOOGLE_TTS_KEY:-}"
TH_VOICE="${TH_VOICE:-th-TH-Standard-A}"
EN_VOICE="${EN_VOICE:-en-US-Standard-C}"
RATE="${RATE:-0.9}"
WORK="$HOME/Desktop/dictation-audio"
LIST_URL="https://raw.githubusercontent.com/siriwarin22/dictation-game/main/words.tsv"

if [ -z "$KEY" ]; then echo "ยังไม่ได้ใส่ API key: รันแบบ GOOGLE_TTS_KEY=คีย์ของคุณ bash -c \"...\""; exit 1; fi
command -v afconvert >/dev/null || { echo "ต้องรันบน Mac เท่านั้น"; exit 1; }

synth(){  # $1 text  $2 language  $3 voice  $4 output .mp3
  local text=${1//\\/\\\\}; text=${text//\"/\\\"}
  local body="{\"input\":{\"text\":\"$text\"},\"voice\":{\"languageCode\":\"$2\",\"name\":\"$3\"},\"audioConfig\":{\"audioEncoding\":\"MP3\",\"speakingRate\":$RATE}}"
  local resp; resp=$(curl -sS -X POST -H "Content-Type: application/json; charset=utf-8" \
    -d "$body" "https://texttospeech.googleapis.com/v1/text:synthesize?key=$KEY")
  local b64; b64=$(printf '%s' "$resp" | tr -d '\n' | sed -n 's/.*"audioContent": *"\([^"]*\)".*/\1/p')
  if [ -z "$b64" ]; then echo; echo "Google ตอบกลับมาไม่มีเสียง:"; printf '%s\n' "$resp" | head -c 600; echo; exit 1; fi
  printf '%s' "$b64" | base64 -D > "$4"
}

rm -rf "$WORK"; mkdir -p "$WORK/audio" "$WORK/tmp"
curl -fsSL "$LIST_URL" -o "$WORK/words.tsv"
echo "เสียงไทย: $TH_VOICE   เสียงอังกฤษ: $EN_VOICE"
synth "สวัสดี" th-TH "$TH_VOICE" "$WORK/tmp/check.mp3"   # fail fast on a bad key or voice name
total=$(wc -l < "$WORK/words.tsv" | tr -d ' ')
n=0; ids=()
while IFS=$'\t' read -r id lang word; do
  [ -z "$id" ] && continue
  n=$((n+1)); printf "\rกำลังสร้างเสียง %d/%d  %s                    " "$n" "$total" "$word"
  if [ "$lang" = "th" ]; then synth "$word" th-TH "$TH_VOICE" "$WORK/tmp/$id.mp3"
  else synth "$word" en-US "$EN_VOICE" "$WORK/tmp/$id.mp3"; fi
  afconvert -f m4af -d aac "$WORK/tmp/$id.mp3" "$WORK/audio/$id.m4a"
  ids+=("\"$id\"")
done < "$WORK/words.tsv"
( IFS=,; echo "{\"voice\":{\"th\":\"$TH_VOICE\",\"en\":\"$EN_VOICE\"},\"ids\":[${ids[*]}]}" ) > "$WORK/audio/manifest.json"
rm -rf "$WORK/tmp"
cd "$WORK" && rm -f ../dictation-audio.zip && zip -qr ../dictation-audio.zip audio
echo
echo "เสร็จแล้ว: ไฟล์ dictation-audio.zip อยู่บน Desktop ($n คำ)"
echo "ส่งไฟล์นี้ให้ Claude ในแชตได้เลย"
