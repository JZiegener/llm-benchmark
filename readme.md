
## Table of Contents

1. [What is this?](#what-is-this)
2. [Prerequisites](#prerequisites)
3. [Getting Started](#getting-started)
4. [Configuration](#configuration)
5. [Running the Benchmark](#running-the-benchmark)
6. [Interpreting the Output](#interpreting-the-output)
7. [Extending the Suite](#extending-the-suite)
8. [Troubleshooting](#troubleshooting)
9. [Contributing](#contributing)
10. [License](#license)

---

## 1. What is this?

This repo ships with a **stand‑alone Bash driver** that:
- Pulls a curated list of LLMs that run comfortably on consumer hardware.
- Runs a set of prompts (stored in `prompts.json`) against every model.
- Measures wall‑clock latency and tokens / s (a very rough estimate of throughput).
- Generates a single `results.json` that contains:
  - **System summary** – CPU, GPU, RAM, OS, etc.
  - **Per‑prompt results** – duration, token count, tokens per second, raw response.

Feel free to drop the repo into any Linux or macOS machine that can run an Ollama daemon.

---

## 2. Prerequisites

| Item | Minimum Version | Notes |
|------|-----------------|-------|
| **Ollama** | 0.1.x (latest) | `ollama serve` must be running in the background. |
| **jq** | 1.6 | JSON processor used by the scripts. |
| **bash** | 4.0+ | For associative arrays & modern features. |
| **lscpu** | – | Usually shipped with coreutils. |
| **lsb_release** | – | Optional, used for OS identification. |
| **nvidia‑smi** | – | Optional, only used to detect an NVIDIA GPU. |

> **Install on Ubuntu/Debian**  
> ```bash
> sudo apt update
> sudo apt install -y jq
> curl -fsSL https://ollama.ai/install.sh | sh
> ```

> **Install on macOS (with Homebrew)**  
> ```bash
> brew install jq
> brew install ollama
> ```

---

## 3. Getting Started

```bash
# Clone this repo
git clone https://github.com/yourname/ollama-benchmark.git
cd ollama-benchmark

# Make sure Ollama daemon is running
ollama serve &          # or use systemd service if you have one
```

---

## 4. Configuration

| File | Purpose | What to edit |
|------|---------|--------------|
| `prompts.json` | The prompts that will be sent to the models | Add, remove or edit the `prompt` field (keeping the `id` and 
`description`). |
| `models.json` | List of models to benchmark | Add any Ollama model name that you want to test. |
| `benchmark.sh` | The driver | Optional: change `PROMPTS_FILE`, `MODELS_FILE` paths, tweak metrics, or run on a specific Ollama 
host by exporting `OLLAMA_HOST`. |

**Tip** – If you only want to test a subset of models, simply delete the others from `models.json` and run `./benchmark.sh` again.

---

## 5. Running the Benchmark

```bash
# From the repo root
./benchmark.sh
```

The script will:

1. Pull every model listed in `models.json` if it isn’t already available locally.
2. Iterate over every prompt in `prompts.json`.
3. For each pair `(model, prompt)`:
   - Record wall‑clock time (in milliseconds).
   - Estimate tokens via a simple word count.
   - Compute tokens / s.
   - Store the full raw output.
4. At the end, write a consolidated `results.json`.

**Output**:

```
=== Ollama LLM Benchmark ===
System: Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz 7.95  NVIDIA GeForce MX250
  Prompts   : 5
  Models    : 6
-> Model: llama3b
   …
✅ Benchmark finished – results in results.json
```

---

## 6. Interpreting the Output

`results.json` is a single, self‑contained JSON file:

```json
{
  "system": {
    "cpu_model": "Intel(R) Core(TM) i5‑8250U CPU @ 1.60GHz",
    "cpu_cores": 4,
    "cpu_mhz": 1800.0,
    "mem_total_gb": 7.95,
    "gpu_model": "NVIDIA GeForce MX250",
    "gpu_ram_gb": 4,
    "os": "Ubuntu 22.04.3 LTS"
  },
  "results": [
    {
      "model": "llama3b",
      "prompt_id": 1,
      "duration_ms": 1203,
      "tokens": 56,
      "tokens_per_s": 46.60,
      "response": "Quantum computing is a branch of computing that uses the principles of quantum mechanics..."
    },
    {
      "model": "gpt-oss",
      "prompt_id": 1,
      "duration_ms": 1450,
      "tokens": 63,
      "tokens_per_s": 43.50,
      "response": "In classical computing, data is stored as bits..."
    },
    …
  ]
}
```

| Field | Meaning |
|-------|---------|
| `system` | Quick hardware & OS snapshot. |
| `results[i]` | A single run of `(model, prompt)`. |
| `duration_ms` | Total time from command launch to the final line of output. |
| `tokens` | Word count of the response – *not* a true token count. |
| `tokens_per_s` | `tokens / (duration_ms / 1000)` – a proxy for throughput. |
| `response` | The exact text printed by Ollama. |

### Common ways to consume the data

| Tool | Command / Idea |
|------|----------------|
| **jq** | `jq '.results[] | select(.model=="llama3b")' results.json` |
| **Excel / Google Sheets** | `jq -r '.results[] | @csv' results.json > results.csv` |
| **Grafana / Kibana** | Import the JSON file into a file‑based data source. |
| **Python** | `import json; data=json.load(open('results.json'))` |

---

## 8. Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `ollama: command not found` | Ollama not installed or not in `$PATH`. | Install Ollama, or add its install location to your 
PATH. |
| `jq: command not found` | jq missing | Install via `apt`, `brew`, or download from <https://stedolan.github.io/jq/>. |
| `nvidia-smi: command not found` | No NVIDIA GPU or driver missing | The script will just report `"None"` for the GPU; no 
failure. |
| `Error: model not found` | Wrong model name in `models.json` | Verify the spelling / existence of the model on 
<https://ollama.ai/library>. |
| `Benchmark takes too long` | CPU‑heavy model on low‑power machine | Remove the model from `models.json` or run on a more 
powerful system. |
| `Error reading prompts.json` | Malformed JSON | Run `jq . prompts.json` to validate the file. |

---

## 9. Contributing

Pull requests are welcome!  
If you’d like to add:

- More lightweight models (e.g., `phi-3-mini`, `orca-2-mini`).
- Better token counting (via HuggingFace tokenizers).
- A Python or Go front‑end that uses the same data model.

Please open an issue first to discuss the scope.

---

## 10. License

MIT © 2024 Your Name  
See the [LICENSE](LICENSE) file.

---

### Final note

The throughput figures in `results.json` are *rough*.  
For production workloads you’ll want a proper tokenizer and a more sophisticated profiling tool (e.g., `perf`, `oprofile`, 
`nvidia-smi`’s `--query-compute-apps`).  
However, for a quick sanity check on a laptop or a cheap VM this script gives you a solid baseline. Happy benchmarking!
