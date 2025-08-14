#!/bin/bash

# Model Download and Quantization Script for Jarvis iOS
# Requires: Python 3.9+, Git, Git LFS, disk space (20GB+)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_ROOT/Models"

# Output Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi

    if ! command -v git-lfs &>/dev/null; then
        log_warn "Git LFS not found, installing..."
        brew install git-lfs
        git lfs install
    fi

    available_space=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$available_space" -lt 20 ]; then
        log_error "Insufficient disk space. Need at least 20GB, have ${available_space}GB"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

setup_python_env() {
    log_info "Setting up Python environment..."
    cd "$PROJECT_ROOT"

    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi

    source venv/bin/activate
    pip install --upgrade pip
    pip install torch torchvision torchaudio transformers huggingface-hub mlc-llm llama-cpp-python
    log_info "Python environment ready"
}

download_models() {
    log_info "Downloading models from Hugging Face..."
    source venv/bin/activate

    mkdir -p "$MODELS_DIR"
    cd "$MODELS_DIR"

    for MODEL in qwen2.5-3b-instruct qwen2.5-4b-instruct; do
        if [ ! -d "$MODEL" ]; then
            log_info "Cloning $MODEL..."
            git clone https://huggingface.co/Qwen/$(echo "$MODEL" | tr a-z A-Z) $MODEL
        else
            log_info "$MODEL already exists, updating..."
            cd $MODEL && git pull && cd ..
        fi
    done
    log_info "Model download completed"
}

quantize_models() {
    log_info "Quantizing models..."
    source venv/bin/activate
    cd "$MODELS_DIR"

    for MODEL in qwen2.5-3b-instruct qwen2.5-4b-instruct; do
        OUT="${MODEL}-q4_K_M.gguf"
        if [ ! -f "$OUT" ]; then
            log_info "Quantizing $MODEL..."
            python -c "
import llama_cpp
from llama_cpp import llama_model_quantize
llama_model_quantize(
    input_path='$MODEL/model.safetensors',
    output_path='$OUT',
    ftype=llama_cpp.LLAMA_FTYPE_MOSTLY_Q4_K_M
)"
        else
            log_info "$MODEL already quantized"
        fi
    done
    log_info "Model quantization completed"
}

convert_to_mlc() {
    log_info "Converting quantized models to MLC format..."
    source venv/bin/activate
    cd "$MODELS_DIR"

    for MODEL in qwen2.5-3b-instruct qwen2.5-4b-instruct; do
        GGUF_FILE="${MODEL}-q4_K_M.gguf"
        OUTPUT_DIR="${MODEL}-q4_K_M.mlc"

        if [ ! -d "$OUTPUT_DIR" ]; then
            log_info "Converting $MODEL to MLC..."
            mlc_llm convert --model $GGUF_FILE --quantization q4f16_1 --target iphone --output $OUTPUT_DIR
        else
            log_info "$MODEL already converted to MLC format"
        fi
    done
    log_info "MLC conversion complete"
}

main() {
    check_prerequisites
    setup_python_env
    download_models
    quantize_models
    convert_to_mlc

    log_info "All steps completed successfully."
}

main
