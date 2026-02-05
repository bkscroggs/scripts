#!/bin/bash
# VERSION 0.4.02 - FIXED AUDIO MAPPING & STREAM INCLUSION

# This version fixes a bug where audio was being dropped due to strict stream mapping.
# It now correctly maps audio streams based on user selection.

VERSION="0.4.02"

# --- 1. THE "GHOSTBUSTER" CLEANUP ---
cleanup() {
    stty sane 2>/dev/null
    tput cnorm 2>/dev/null
    pkill -P $$ 2>/dev/null
    rm -f /tmp/ffmpeg_batch_*.log 2>/dev/null
}

trap 'cleanup; echo -e "\n\n\e[1;31m⚠️  INTERRUPTED: Terminal Restored.\e[0m"; exit 1' SIGINT SIGTERM
trap cleanup EXIT

# --- 2. VERSION FLAG ---
if [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "Video Compression Studio Version $VERSION"
    exit 0
fi

# --- 3. HARDWARE DETECTION ---
detect_hardware() {
    TOTAL_CORES=$(nproc)
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | xargs)
    [[ -z "$TOTAL_CORES" ]] && TOTAL_CORES=4
}
detect_hardware

# --- 4. DEPENDENCY CHECK ---
check_dependencies() {
    local missing=()
    for cmd in ffmpeg ffprobe bc cpulimit; do
        if ! command -v $cmd &> /dev/null; then missing+=("$cmd"); fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "\e[1;33m⚠️  Missing: ${missing[*]}\e[0m"
        echo -ne "👉 Install now? (y/N): "; read -r choice
        [[ "$choice" =~ ^[Yy]$ ]] && sudo apt update && sudo apt install "${missing[@]}" -y || exit 1
    fi
}
check_dependencies

# --- MAIN PROGRAM ---
compressVid_batch() {
  local crf=28; local preset="medium"; local audio_mode="none" 
  local max_width=0; local cpu_limit=100; local recursive="n"
  local total_orig_bytes=0; local total_comp_bytes=0; local file_count=0
  local skipped_count=0; local start_dir=$(pwd)

  clear
  echo -e "\e[1;36m========================================================\e[0m"
  echo -e "         🎬 VIDEO COMPRESSION STUDIO v$VERSION            "
  echo -e "========================================================\e[0m"
  echo -e "🖥️  SYSTEM: \e[1;35m$CPU_MODEL\e[0m"
  echo -e "⚙️  CORES:  \e[1;35m$TOTAL_CORES Processors Detected\e[0m"
  echo -e "🧠 RAM OPTIMIZATION: \e[1;32mEnabled (/tmp/tmpfs log redirect)\e[0m"
  echo -e "--------------------------------------------------------"
  
  echo -ne "📂 Search for videos recursively? (y/N): "
  read -r recursive
  
  local find_args=(".")
  [[ ! "$recursive" =~ ^[Yy]$ ]] && find_args+=("-maxdepth" "1")

  echo -e "🔍 Scanning for video files..."
  unset files; declare -a files
  while IFS= read -r -d '' file; do 
    [[ "$file" == *"CompressedVideos"* ]] && continue
    files+=("$file")
  done < <(find "${find_args[@]}" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.webm" -o -iname "*.3gp" -o -iname "*.3g2" -o -iname "*.vob" -o -iname "*.ts" \) -print0)

  if [ ${#files[@]} -eq 0 ]; then
    echo -e "\n\e[1;31m❌ ERROR: No video files found.\e[0m"; return 1
  fi
  echo -e "✅ Found \e[1;32m${#files[@]}\e[0m video files."

  # --- CONFIGURATION WIZARD ---
  echo -e "\n\e[1;32m[SETTING UP COMPRESSION PARAMETERS]\e[0m"
  echo -e "\n\e[1;33m1. VISUAL QUALITY (CRF)\e[0m"
  echo "Lower = Better Quality. [18: Lossless, 23: High, 28: Balanced, 32: Small File]"
  echo -ne "   👉 Select Option (1-4) \e[1;32m[28]\e[0m: "; read -r input
  case "$input" in 1) crf=18 ;; 2) crf=23 ;; 4) crf=32 ;; *) crf=${input:-28} ;; esac

  echo -e "\n\e[1;33m2. ENCODING PRESET (SPEED VS SIZE)\e[0m"
  echo "Determines CPU 'effort'. [1: Ultrafast, 4: Medium, 6: VerySlow]"
  echo -ne "   👉 Select Option (1-6) \e[1;32m[4]\e[0m: "; read -r input
  case "$input" in 1) preset="ultrafast";; 2) preset="veryfast";; 3) preset="fast";; 5) preset="slow";; 6) preset="veryslow";; *) preset="medium";; esac

  echo -e "\n\e[1;33m3. RESOLUTION LIMIT\e[0m"
  echo "Resize to save space. [1: Original, 2: 1080p, 3: 720p]"
  echo -ne "   👉 Select Option (1-3) \e[1;32m[1]\e[0m: "; read -r input
  case "$input" in 2) max_width=1920;; 3) max_width=1280;; *) max_width=0;; esac

  echo -e "\n\e[1;33m4. AUDIO STRATEGY\e[0m"
  echo "[1: Mute, 2: Compress AAC, 3: Copy Original]"
  echo -ne "   👉 Select Option (1-3) \e[1;32m[1]\e[0m: "; read -r input
  case "$input" in 2) audio_mode="compress";; 3) audio_mode="copy";; *) audio_mode="none";; esac

  echo -e "\n\e[1;33m5. CPU LOAD LIMIT\e[0m"
  echo "Prevents system lockups. Recommendation: 80% for stability."
  echo -ne "   👉 Enter Max System % (1-100) \e[1;32m(100)\e[0m: "; read -r input; cpu_limit=${input:-100}

  echo -e "\n\e[1;36m🚀 Initializing... Audio fixes applied.\e[0m"
  sleep 1; tput civis; stty -echo 

  get_temp() {
    local temp=0
    for zone in /sys/class/thermal/thermal_zone*; do
      if [ -f "$zone/type" ] && grep -qiE "package|x86_pkg|cpu" "$zone/type"; then
        temp=$(cat "$zone/temp" 2>/dev/null); echo $((temp / 1000)); return
      fi
    done
    echo 0
  }

  for f in "${files[@]}"; do
    dir_name=$(dirname "$f"); base_name=$(basename "$f"); file_stem="${base_name%.*}"
    target_dir="$dir_name/CompressedVideos"; mkdir -p "$target_dir"
    outfile="$target_dir/${file_stem}_compressed.mp4"
    job_log="/tmp/ffmpeg_batch_$(date +%s).log"

    echo -e "\e[1;37m--------------------------------------------------------\e[0m"
    echo -e "🔎 \e[1;34mChecking:\e[0m $base_name"
    
    if [[ -f "$outfile" ]]; then
        echo -ne "   ┗━ ⏳ Validating existing file... "
        if ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$outfile" &>/dev/null; then
            echo -e "[\e[1;32m PASS \e[0m]"; echo -e "   ┗━ ⏭️  Skipping."
            ((skipped_count++))
            total_orig_bytes=$((total_orig_bytes + $(stat -c%s "$f")))
            total_comp_bytes=$((total_comp_bytes + $(stat -c%s "$outfile")))
            ((file_count++))
            continue
        else
            echo -e "[\e[1;31m FAIL \e[0m]"; echo -e "   ┗━ 🗑️  Removing partial file."
            rm -f "$outfile"
        fi
    fi

    echo -e "   ┗━ 🎥 \e[1;33mAction:\e[0m Encoding Streams..."
    orig_dur=$(ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=nw=1:nk=1 "$f" 2>/dev/null || echo 1)
    orig_size=$(stat -c%s "$f")

    # FIXED AUDIO MAPPING LOGIC
    ff_audio="-an"; ff_map="-map 0:v:0"
    if [[ "$audio_mode" == "copy" ]]; then
        ff_audio="-c:a copy"
        ff_map="-map 0:v:0 -map 0:a?" # Map video AND all audio if present
    elif [[ "$audio_mode" == "compress" ]]; then
        ff_audio="-c:a aac -b:a 128k"
        ff_map="-map 0:v:0 -map 0:a?"
    fi

    ff_filters=""; [[ "$max_width" -gt 0 ]] && ff_filters="scale='min(${max_width},iw)':-1"
    filter_flag=""; [[ -n "$ff_filters" ]] && filter_flag="-vf $ff_filters"

    nice -n 15 ffmpeg -hide_banner -y -i "$f" $ff_map -c:v libx265 -crf "$crf" -preset "$preset" \
      -pix_fmt yuv420p -tag:v hvc1 -movflags +faststart \
      $ff_audio $filter_flag -stats "$outfile" < /dev/null > "$job_log" 2>&1 &
    FF_PID=$!

    [[ "$cpu_limit" -lt 100 ]] && { cpulimit -p $FF_PID -l $((TOTAL_CORES * cpu_limit)) -b & LIMIT_PID=$!; }

    local paused=false
    while kill -0 $FF_PID 2>/dev/null; do
        current_temp=$(get_temp)
        if (( current_temp > 85 )) && [[ "$paused" == false ]]; then
            kill -STOP $FF_PID; paused=true
        elif (( current_temp < 72 )) && [[ "$paused" == true ]]; then
            kill -CONT $FF_PID; paused=false
        fi

        if [[ "$paused" == true ]]; then
            echo -ne "\r   ┗━ 🔥 \e[1;31mCOOLDOWN: $current_temp°C. Paused...\e[0m\e[K"
        else
            line=$(grep -o "time=[0-9:.]*" "$job_log" | tail -1)
            if [[ $line =~ time=([0-9:.]+) ]]; then
                cur_time="${BASH_REMATCH[1]}"; IFS=: read -r h m s <<< "$cur_time"
                h=${h#0}; h=${h:-0}; m=${m#0}; m=${m:-0}; s_int=${s%.*}; s_int=${s_int#0}; s_int=${s_int:-0}
                cur_sec=$(( h*3600 + m*60 + s_int ))
                perc=$(echo "($cur_sec * 100 / $orig_dur)" | bc 2>/dev/null || echo 0)
                (( perc > 100 )) && perc=100
                proc_cpu=$(ps -p "$FF_PID" -o %cpu= | tr -d ' ')
                total_use=$(echo "scale=1; $proc_cpu / $TOTAL_CORES" | bc -l | cut -d. -f1)
                printf "\r   ┗━ ⏳ [%-20s] %d%% | CPU: %s%% | Temp: %s°C\e[K" "$(printf '#%.0s' $(seq 1 $((perc/5))))" "$perc" "${total_use:-0}" "$current_temp"
            fi
        fi
        sleep 2
    done
    [[ -n "$LIMIT_PID" ]] && kill $LIMIT_PID 2>/dev/null
    
    if [[ -f "$outfile" ]]; then
        total_orig_bytes=$((total_orig_bytes + orig_size))
        total_comp_bytes=$((total_comp_bytes + $(stat -c%s "$outfile")))
        ((file_count++))
        echo -e "\n   ┗━ ✅ \e[1;32mSuccess!\e[0m"
    fi
    rm -f "$job_log"
  done

  stty echo; tput cnorm
  orig_gb=$(echo "scale=2; $total_orig_bytes / 1073741824" | bc)
  comp_gb=$(echo "scale=2; $total_comp_bytes / 1073741824" | bc)
  saved_gb=$(echo "scale=2; ($total_orig_bytes - $total_comp_bytes) / 1073741824" | bc)
  [[ "$total_orig_bytes" -gt 0 ]] && perc_saved=$(echo "scale=1; ($total_orig_bytes - $total_comp_bytes) * 100 / $total_orig_bytes" | bc) || perc_saved=0

  {
    echo "=========================================="
    echo "COMPRESSION MASTER REPORT - $(date)"
    echo "=========================================="
    echo "Total Files Scanned: ${#files[@]}"
    echo "Files Processed:     $file_count (Resumed: $skipped_count)"
    echo "Original Total:      $orig_gb GB"
    echo "Compressed Total:    $comp_gb GB"
    echo "Storage Saved:       $saved_gb GB ($perc_saved%)"
    echo "=========================================="
  } > "$start_dir/compressionResults.txt"

  echo -e "\n\e[1;36m--------------------------------------------------------\e[0m"
  echo -e "🏁 BATCH COMPLETE! Total Saved: \e[1;32m$saved_gb GB\e[0m"
  echo -e "📄 Report: $start_dir/compressionResults.txt"
  echo -e "\e[1;36m--------------------------------------------------------\e[0m"
}

compressVid_batch
# VERSION 0.4.02
