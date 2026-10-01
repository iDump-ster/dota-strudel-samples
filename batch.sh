cat > batch.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

set -u

# =========================
# CONFIG
# =========================

BATCH_SIZE=50

URLS="dota2_sounds.txt"
SAMPLE_DIR="samples"
STATE_DIR=".sample_state"

# =========================
# SETUP
# =========================

mkdir -p "$SAMPLE_DIR"
mkdir -p "$STATE_DIR"

touch "$STATE_DIR/done.txt"
touch "$STATE_DIR/failed.txt"

TOTAL=$(grep -c '^https\?://' "$URLS")

echo
echo "======================================"
echo " DOTA SAMPLE BATCH DOWNLOADER"
echo "======================================"
echo "URLs:        $TOTAL"
echo "Batch size:  $BATCH_SIZE"
echo "Local dir:   $SAMPLE_DIR"
echo "======================================"
echo

# =========================
# DOWNLOAD ONE FILE
# =========================

download_one() {
    url="$1"

    filename=$(basename "${url%%\?*}")
    dest="$SAMPLE_DIR/$filename"
    tmp="$dest.part"

    # Already successfully processed?
    if grep -Fxq "$url" "$STATE_DIR/done.txt"; then
        return 0
    fi

    # Already exists locally and is valid?
    if [ -f "$dest" ]; then
        if file "$dest" | grep -qiE 'audio|mpeg|ogg|wave'; then
            echo "$url" >> "$STATE_DIR/done.txt"
            return 0
        fi
        rm -f "$dest"
    fi

    echo "↓ $filename"

    # Download quietly, follow redirects, fail on HTTP errors.
    if ! curl -L \
        --fail \
        --silent \
        --show-error \
        --retry 3 \
        --connect-timeout 15 \
        --max-time 120 \
        -A "Mozilla/5.0" \
        -o "$tmp" \
        "$url"
    then
        echo "  DOWNLOAD FAILED"
        rm -f "$tmp"
        echo "$url" >> "$STATE_DIR/failed.txt"
        return 1
    fi

    # Make sure we didn't download HTML instead of audio.
    if ! file "$tmp" | grep -qiE 'audio|mpeg|ogg|wave'; then
        echo "  NOT AUDIO — deleting"
        echo "$url" >> "$STATE_DIR/failed.txt"
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$dest"

    echo "$url" >> "$STATE_DIR/done.txt"

    echo "  ✓ $filename"

    return 0
}

# =========================
# PROCESS BATCH
# =========================

batch=0
processed=0

while true; do

    # Build the next batch of URLs that aren't finished.
    mapfile -t BATCH < <(
        grep '^https\?://' "$URLS" |
        grep -Fvx -f "$STATE_DIR/done.txt" |
        head -n "$BATCH_SIZE"
    )

    # Nothing left.
    if [ "${#BATCH[@]}" -eq 0 ]; then
        break
    fi

    batch=$((batch + 1))

    echo
    echo "======================================"
    echo " BATCH $batch"
    echo " ${#BATCH[@]} files"
    echo "======================================"

    for url in "${BATCH[@]}"; do
        download_one "$url"
        processed=$((processed + 1))
    done

    echo
    echo "Downloaded this batch."

    # =========================
    # GIT
    # =========================

    echo "Adding samples to git..."

    git add "$SAMPLE_DIR" "$STATE_DIR"

    if git diff --cached --quiet; then
        echo "Nothing new to commit."
    else
        git commit -m "Add Dota sample batch $batch"

        echo "Pushing..."

        if ! git push; then
            echo
            echo "!!! GIT PUSH FAILED !!!"
            echo "Samples are being KEPT locally."
            echo "Fix GitHub authentication/network and rerun."
            exit 1
        fi
    fi

    # =========================
    # DELETE LOCAL AUDIO
    # =========================

    echo "Push successful."
    echo "Cleaning local audio..."

    rm -f "$SAMPLE_DIR"/*

    echo "Local batch deleted."
    echo
    echo "Progress: $(wc -l < "$STATE_DIR/done.txt") / $TOTAL"
    echo

done

echo
echo "======================================"
echo " COMPLETE"
echo "======================================"
echo "Successful: $(wc -l < "$STATE_DIR/done.txt")"
echo "Failed:     $(wc -l < "$STATE_DIR/failed.txt")"
echo
echo "Failed URLs:"
cat "$STATE_DIR/failed.txt"
echo
EOF

chmod +x batch.sh