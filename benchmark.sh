#!/usr/bin/env bash
# -------------------------------------------------------------
#  Benchmark Ollama LLMs against a set of prompts
#  Author:  ChatGPT
#  Date:    2025‑11‑16
# -------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------------------
# Configuration – adjust if you store the files elsewhere
# ------------------------------------------------------------------
PROMPTS_FILE="prompts.json"
MODELS_FILE="models.json"
RESULTS_FILE="results.json"
TMP_RESULTS="tmp_results.json"

# ------------------------------------------------------------------
# Helper – gather a compact system summary
# ------------------------------------------------------------------
function get_system_info() {
    # CPU
    cpu_model=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
    cpu_cores=$(lscpu | awk -F: '/^CPU\(s\)/ {print $2}' | xargs)
    cpu_mhz=$(lscpu | awk -F: '/CPU MHz/ {print $2}' | xargs | awk '{printf "%.1f", $1}')

    # RAM
    mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_total_gb=$(awk "BEGIN{printf \"%.2f\", $mem_total_kb/1024/1024}")

    # GPU (if NVIDIA)
    if command -v nvidia-smi &>/dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null)
        gpu_model=$(echo "$gpu_info" | awk -F, '{print $1}' | xargs)
        gpu_ram_gb=$(echo "$gpu_info" | awk -F, '{print $2}' | xargs)
    else
        gpu_model="None"
        gpu_ram_gb="0"
    fi

    # OS
    if command -v lsb_release &>/dev/null; then
        os_info=$(lsb_release -d -s)
    else
        os_info=$(uname -s " " uname -r)
    fi

    # Build JSON with jq
    jq -n \
        --arg cpu_model "$cpu_model" \
        --arg cpu_cores "$cpu_cores" \
        --arg cpu_mhz "$cpu_mhz" \
        --arg mem_total_gb "$mem_total_gb" \
        --arg gpu_model "$gpu_model" \
        --arg gpu_ram_gb "$gpu_ram_gb" \
        --arg os "$os_info" \
        '{cpu_model: $cpu_model,
          cpu_cores: ($cpu_cores | tonumber),
          cpu_mhz: ($cpu_mhz | tonumber),
          mem_total_gb: ($mem_total_gb | tonumber),
          gpu_model: $gpu_model,
          gpu_ram_gb: ($gpu_ram_gb | tonumber),
          os: $os}'
}

# ------------------------------------------------------------------
# Helper – run a single prompt against a single model
# ------------------------------------------------------------------
function benchmark_once() {
    local model="$1"
    local prompt_id="$2"
    local prompt="$3"

    local start_ns=$(date +%s%N)
    local output
    output=$(ollama run "$model" "$prompt")
    local end_ns=$(date +%s%N)

    local duration_ms=$(( (end_ns - start_ns) / 1000000 ))
    local duration_s=$(( duration_ms / 1000 ))
    [ "$duration_s" -eq 0 ] && duration_s=1   # avoid div‑by‑zero

    # Simple token count – words = approximate tokens
    local tokens=$(echo "$output" | wc -w | tr -d '[:space:]')
    local tokens_per_s=$(awk "BEGIN{printf \"%.2f\", $tokens / $duration_s}")

    # Build JSON result
    jq -n \
        --arg model "$model" \
        --argjson prompt_id "$prompt_id" \
        --argjson duration_ms "$duration_ms" \
        --argjson tokens "$tokens" \
        --argjson tokens_per_s "$tokens_per_s" \
        --arg response "$output" \
        '{model: $model,
          prompt_id: $prompt_id,
          duration_ms: $duration_ms,
          tokens: $tokens,
          tokens_per_s: $tokens_per_s,
          response: $response}'
}

# ------------------------------------------------------------------
# Main script
# ------------------------------------------------------------------
echo "=== Ollama LLM Benchmark ==="

# 1. Grab system info
sys_info=$(get_system_info)
echo "System: $(echo "$sys_info" | jq -r '. | .cpu_model, .mem_total_gb, .gpu_model')"

# 2. Load the banks
prompt_count=$(jq 'length' "$PROMPTS_FILE")
model_count=$(jq 'length' "$MODELS_FILE")

echo "  Prompts   : $prompt_count"
echo "  Models    : $model_count"

# 2. Initialise temporary file
> "$TMP_RESULTS"

# 3. Loop over models ➜ prompts
for model in $(jq -r '.[].' "$MODELS_FILE"); do
    echo "-> Model: $model"

    # Pull the model if it isn’t already present
    ollama show "$model" &>/dev/null || \
        { echo "   ❌ Model $model not found locally – pulling…" &&
          ollama pull "$model"; }

    # Run all prompts for this model
    for prompt_id in $(seq 1 $(jq 'length' "$PROMPTS_FILE")); do
        prompt=$(jq -r ".[$((prompt_id-1))].prompt" "$PROMPTS_FILE")
        res=$(benchmark_once "$model" "$prompt_id" "$prompt")
        echo "$res" >> "$TMP_RESULTS"
    done
done

# 4. Build final JSON
echo "=== Wrapping up ==="
system_json=$(get_system_info)

# Aggregate all per‑model results into an array
results_json=$(cat "$TMP_RESULTS" | jq -s '.')

jq -n \
    --argjson system "$system_json" \
    --argjson results "$results_json" \
    '{system: $system,
      results: $results}' \
    > "$RESULTS_FILE"

# Clean‑up temporary file
rm -f "$TMP_RESULTS"

echo "✅ Benchmark finished – results in $RESULTS_FILE"
echo "    See the JSON output for a quick‑look summary."
