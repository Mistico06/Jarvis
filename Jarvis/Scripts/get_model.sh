#!/bin/bash

# Model Download and Quantization Script for Jarvis iOS
# Requires: Python 3.9+, Git, sufficient disk space (20GB+)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_ROOT/Models"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check Git LFS
    if ! command -v git-lfs &> /dev/null; then
        log_warn "Git LFS not found, installing..."
        brew install git-lfs
        git lfs install
    fi
    
    # Check available disk space (require 20GB)
    available_space=$(df -BG "$PROJECT_ROOT" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$available_space" -lt 20 ]; then
        log_error "Insufficient disk space. Need at least 20GB, have ${available_space}GB"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Setup Python environment
setup_python_env() {
    log_info "Setting up Python environment..."
    
    cd "$PROJECT_ROOT"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Install/upgrade pip
    pip install --upgrade pip
    
    # Install required packages
    pip install torch torchvision torchaudio
    pip install transformers
    pip install huggingface-hub
    pip install mlc-llm
    pip install llama-cpp-python
    
    log_info "Python environment ready"
}

# Download models from Hugging Face
download_models() {
    log_info "Downloading models from Hugging Face..."
    
    source venv/bin/activate
    
    mkdir -p "$MODELS_DIR"
    cd "$MODELS_DIR"
    
    # Download Qwen2.5-3B-Instruct (Lite model)
    if [ ! -d "qwen2.5-3b-instruct" ]; then
        log_info "Downloading Qwen2.5-3B-Instruct..."
        git clone https://huggingface.co/Qwen/Qwen2.5-3B-Instruct qwen2.5-3b-instruct
    else
        log_info "Qwen2.5-3B-Instruct already exists, updating..."
        cd qwen2.5-3b-instruct
        git pull
        cd ..
    fi
    
    # Download Qwen2.5-4B-Instruct (Max model) 
    if [ ! -d "qwen2.5-4b-instruct" ]; then
        log_info "Downloading Qwen2.5-4B-Instruct..."
        git clone https://huggingface.co/Qwen/Qwen2.5-4B-Instruct qwen2.5-4b-instruct
    else
        log_info "Qwen2.5-4B-Instruct already exists, updating..."
        cd qwen2.5-4b-instruct
        git pull
        cd ..
    fi
    
    log_info "Model download completed"
}

# Quantize models to Q4_K_M format
quantize_models() {
    log_info "Quantizing models to Q4_K_M format..."
    
    source venv/bin/activate
    cd "$MODELS_DIR"
    
    # Quantize Lite model
    if [ ! -f "qwen2.5-3b-instruct-q4_K_M.gguf" ]; then
        log_info "Quantizing Qwen2.5-3B-Instruct..."
        python -c "
import llama_cpp
from llama_cpp import llama_model_quantize

llama_model_quantize(
    input_path='qwen2.5-3b-instruct/model.safetensors',
    output_path='qwen2.5-3b-instruct-q4_K_M.gguf',
    ftype=llama_cpp.LLAMA_FTYPE_MOSTLY_Q4_K_M
)
print('Lite model quantization completed')
"
    else
        log_info "Lite model already quantized"
    fi
    
    # Quantize Max model
    if [ ! -f "qwen2.5-4b-instruct-q4_K_M.gguf" ]; then
        log_info "Quantizing Qwen2.5-4B-Instruct..."
        python -c "
import llama_cpp
from llama_cpp import llama_model_quantize

llama_model_quantize(
    input_path='qwen2.5-4b-instruct/model.safetensors',
    output_path='qwen2.5-4b-instruct-q4_K_M.gguf',
    ftype=llama_cpp.LLAMA_FTYPE_MOSTLY_Q4_K_M
)
print('Max model quantization completed')
"
    else
        log_info "Max model already quantized"
    fi
    
    log_info "Model quantization completed"
}

# Convert to MLC format for iOS optimization
convert_to_mlc() {
    log_info "Converting models to MLC format for iOS..."
    
    source venv/bin/activate
    cd "$MODELS_DIR"
    
    # Convert Lite model
    if [ ! -d "qwen2.5-3b-instruct-q4_K_M.mlc" ]; then
        log_info "Converting Lite model to MLC format..."
        mlc_llm convert_weight \
            --model qwen2.5-3b-instruct \
            --quantization q4f16_1 \
            --output qwen2.5-3b-instruct-q4_K_M.mlc
    fi
    
    # Convert Max model
    if [ ! -d "qwen2.5-4b-instruct-q4_K_M.mlc" ]; then
        log_info "Converting Max model to MLC format..."
        mlc_llm convert_weight \
            --model qwen2.5-4b-instruct \
            --quantization q4f16_1 \
            --output qwen2.5-4b-instruct-q4_K_M.mlc
    fi
    
    log_info "MLC conversion completed"
}

# Generate model metadata
generate_metadata() {
    log_info "Generating model metadata..."
    
    cd "$MODELS_DIR"
    
    # Create model info JSON
    cat > model_info.json << EOF
{
  "models": {
    "lite": {
      "name": "Qwen2.5-3B-Instruct",
      "quantization": "Q4_K_M",
      "context_length": 4096,
      "max_tokens": 512,
      "file_size_mb": $(du -m qwen2.5-3b-instruct-q4_K_M.gguf 2>/dev/null | cut -f1 || echo "0"),
      "recommended_for": "Fast responses, basic tasks",
      "target_tokens_per_second": 8
    },
    "max": {
      "name": "Qwen2.5-4B-Instruct", 
      "quantization": "Q4_K_M",
      "context_length": 4096,
      "max_tokens": 512,
      "file_size_mb": $(du -m qwen2.5-4b-instruct-q4_K_M.gguf 2>/dev/null | cut -f1 || echo "0"),
      "recommended_for": "Complex reasoning, coding tasks",
      "target_tokens_per_second": 6
    }
  },
  "generation_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_size_mb": $(du -sm . | cut -f1)
}
EOF
    
    log_info "Model metadata generated"
}

# Main execution
main() {
    log_info "Starting Jarvis model preparation for iPhone 16 A18..."
    
    check_prerequisites
    setup_python_env
    download_models
    quantize_models
    convert_to_mlc
    generate_metadata
    
    log_info "Model preparation completed successfully!"
    log_info "Next steps:"
    log_info "1. Run './ios_pack.sh' to package models for iOS"
    log_info "2. Run './build_app.sh' to build the complete app"
    log_info "3. Models are ready for iPhone 16 A18 deployment"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
