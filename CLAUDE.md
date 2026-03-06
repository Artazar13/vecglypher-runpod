# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VecGlypher-RunPod is a deployment package for running VecGlypher (a 27B parameter language model for SVG glyph generation) on RunPod GPU instances. The project provides scripts to automatically set up the environment, download the model, and run both a vLLM inference server and a Streamlit web interface.

**Target Hardware**: RunPod GPU Pod with 96GB+ VRAM (H100 96GB recommended)
**Model**: VecGlypher-27b-it (~50GB download)

---

## Common Commands

### Initial Setup (First Time)
```bash
chmod +x install_and_run.sh
./install_and_run.sh
```
This one-shot script handles everything: installs Miniconda, creates conda environment, downloads dependencies, downloads the model, and starts both services.

### Quick Start (After Setup)
```bash
chmod +x run.sh
./run.sh
```
Use this for subsequent runs - skips setup and directly starts vLLM server and Streamlit UI.

### Manual Startup (Two Terminals)

**Terminal 1 - vLLM Server:**
```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate svg_glyph_llm_eval
cd /workspace/VecGlypher
vllm serve saves/VecGlypher-27b-it --host 0.0.0.0 --port 30000 -tp 1 -dp 1 --enable-log-requests
```

**Terminal 2 - Streamlit UI:**
```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate svg_glyph_llm_eval
cd /workspace/VecGlypher
streamlit run src/tools/sft_data_visualizer.py --server.port 8443
```

### Debugging
```bash
# Check vLLM logs
tail -f /tmp/vllm_server.log

# Check GPU status
nvidia-smi

# Verify vLLM is running
curl http://localhost:30000/v1/models
```

---

## Architecture

The system consists of two separate processes:

1. **vLLM Server** (port 30000) - High-performance inference server serving the VecGlypher-27b-it model using OpenAI-compatible API endpoints

2. **Streamlit UI** (port 8443) - Web interface (`src/tools/sft_data_visualizer.py`) that communicates with the vLLM server to generate glyphs

3. **Jupyter Notebook** (`VecGlypher_UI.ipynb`) - Alternative interface for programmatic glyph generation with batch processing support

### Communication Flow
```
User → Streamlit (8443) → vLLM API (30000) → VecGlypher Model → SVG Output
```

The vLLM server exposes an OpenAI-compatible `/v1/chat/completions` endpoint that the UI uses for inference.

---

## Directory Structure

```
/workspace/VecGlypher/
├── install_and_run.sh       # Full setup + launch script
├── run.sh                    # Quick launch for already-set-up environments
├── VecGlypher_UI.ipynb       # Jupyter notebook for programmatic access
├── env.txt                   # HuggingFace token (DO NOT COMMIT actual token)
├── saves/
│   └── VecGlypher-27b-it/    # Model weights (~50GB, downloaded from HF)
├── outputs/                  # Generated SVG glyphs
├── hf_cache/                 # HuggingFace download cache
├── src/                      # VecGlypher source code (from upstream repo)
└── .env                      # Created during setup, contains HF_TOKEN
```

---

## Configuration Notes

- **Conda Environment Name**: `svg_glyph_llm_eval` (Python 3.11)
- **Model Path**: `saves/VecGlypher-27b-it`
- **vLLM Port**: 30000
- **Streamlit Port**: 8443
- **Required Open Ports on RunPod**: 8443 and 30000

The installation uses prebuilt wheels for `flash-attn` to avoid compilation on the Pod. Key dependencies include:
- `vllm==0.11.0` (with CUDA 12.8 backend)
- `transformers==4.57.3`
- `flash_attn` (prebuilt wheel for CUDA 12.8)
- `torchmetrics`, `openai-clip`, `lpips`

---

## Model Access

The model requires a HuggingFace token with appropriate access permissions. During setup, the token is saved to `.env` with chmod 600 permissions. The token should start with `hf_`.

---

## Streamlit UI Location

The Streamlit interface runs from `src/tools/sft_data_visualizer.py` which is located in the VecGlypher repository cloned during setup. This file is NOT in the current directory - it's part of the cloned upstream repository.
