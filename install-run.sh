#!/bin/bash
# ============================================================
# VecGlypher — Установка и запуск одной командой
# ============================================================

set -e

VLLM_PORT=30000
STREAMLIT_PORT=8443
MODEL_REPO="VecGlypher/VecGlypher-27b-it"
MODEL_LOCAL="saves/VecGlypher-27b-it"
CONDA_ENV="svg_glyph_llm_eval"
WORKDIR="/workspace/VecGlypher"

# ------------------------------------------------------------
# Цвета для красивого вывода
# ------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${YELLOW}➡️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }

echo ""
echo "============================================================"
echo "        VecGlypher — Установка и запуск"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# Шаг 1 — Спрашиваем токен один раз
# ------------------------------------------------------------
if [ -f "${WORKDIR}/.env" ] && grep -q "HF_TOKEN=hf_" "${WORKDIR}/.env" 2>/dev/null; then
    ok "HuggingFace токен уже сохранён"
    source "${WORKDIR}/.env"
else
    echo -n "🔑 Введите ваш HuggingFace токен (hf_...): "
    read -s HF_TOKEN
    echo ""
    if [[ ! "${HF_TOKEN}" == hf_* ]]; then
        err "Токен должен начинаться с hf_"
    fi
    ok "Токен принят"
fi

# ------------------------------------------------------------
# Шаг 2 — Conda
# ------------------------------------------------------------
info "Проверяем Miniconda..."
if [ ! -d "/workspace/miniconda3" ]; then
    info "Устанавливаем Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p /workspace/miniconda3
    rm /tmp/miniconda.sh
fi
source /workspace/miniconda3/etc/profile.d/conda.sh
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true
ok "Miniconda готова"

# ------------------------------------------------------------
# Шаг 3 — Репозиторий
# ------------------------------------------------------------
info "Проверяем репозиторий..."
if [ ! -d "${WORKDIR}" ]; then
    info "Клонируем репозиторий..."
    git clone https://github.com/xk-huang/VecGlypher.git ${WORKDIR}
fi
cd ${WORKDIR}
ok "Репозиторий готов"

# ------------------------------------------------------------
# Шаг 4 — Сохраняем .env
# ------------------------------------------------------------
info "Сохраняем токен в .env..."
mkdir -p data saves outputs misc third_party hf_cache
cat > .env << EOF
HF_TOKEN=${HF_TOKEN}
HF_HOME=hf_cache/
EOF
chmod 600 .env
ok "Токен сохранён в .env (права 600)"

# ------------------------------------------------------------
# Шаг 5 — Conda окружение
# ------------------------------------------------------------
info "Проверяем conda окружение..."
if ! conda env list | grep -q "${CONDA_ENV}"; then
    info "Создаём окружение Python 3.11..."
    conda create -n ${CONDA_ENV} -y python=3.11
fi
conda activate ${CONDA_ENV}
ok "Окружение активировано"

# ------------------------------------------------------------
# Шаг 6 — Зависимости
# ------------------------------------------------------------
info "Проверяем зависимости..."
if ! python -c "import vllm" 2>/dev/null; then
    info "Устанавливаем зависимости (5-10 минут)..."
    pip install -q uv
    uv pip install -r requirements.txt
    uv pip install transformers==4.57.3 vllm==0.11.0 --torch-backend=cu128
    info "Устанавливаем flash-attn (prebuilt wheel, без компиляции)..."
    FLASH_WHEEL="https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.5.4/flash_attn-2.8.3+cu128torch2.8-cp311-cp311-linux_x86_64.whl"
    uv pip install "${FLASH_WHEEL}"
    uv pip install flashinfer-python==0.3.1.post1
    uv pip install torchmetrics==1.8.1 openai-clip==1.0.1 lpips==0.1.4
fi
if ! python -c "import hf_transfer" 2>/dev/null; then
    pip install -q hf_transfer
fi
ok "Все зависимости установлены"

# ------------------------------------------------------------
# Шаг 7 — Скачиваем модель
# ------------------------------------------------------------
info "Проверяем веса модели..."
if [ ! -f "${MODEL_LOCAL}/config.json" ]; then
    info "Скачиваем модель (~50GB, это займёт несколько минут)..."
    export HF_TOKEN=${HF_TOKEN}
    hf download ${MODEL_REPO} \
        --local-dir ${MODEL_LOCAL} \
        --token ${HF_TOKEN}
    ok "Модель скачана"
else
    ok "Модель уже скачана"
fi

# ------------------------------------------------------------
# Шаг 8 — Запуск vLLM сервера
# ------------------------------------------------------------
info "Запускаем vLLM сервер на порту ${VLLM_PORT}..."
vllm serve ${MODEL_LOCAL} \
    --host 0.0.0.0 \
    --port ${VLLM_PORT} \
    -tp 1 -dp 1 \
    --enable-log-requests \
    > /tmp/vllm_server.log 2>&1 &
VLLM_PID=$!

echo "   Ждём загрузки модели в GPU..."
for i in $(seq 1 60); do
    sleep 5
    if curl -s http://localhost:${VLLM_PORT}/v1/models > /dev/null 2>&1; then
        ok "vLLM сервер готов! (~$((i*5)) сек)"
        break
    fi
    if ! kill -0 ${VLLM_PID} 2>/dev/null; then
        err "vLLM упал! Лог: /tmp/vllm_server.log"
    fi
    echo -ne "   ⏳ $((i*5)) сек...\r"
done

# ------------------------------------------------------------
# Шаг 9 — Запуск Streamlit
# ------------------------------------------------------------
echo ""
ok "Всё готово! Открывайте в браузере:"
echo ""
echo "   🌐 https://ВАШ_POD_ID-${STREAMLIT_PORT}.proxy.runpod.net"
echo ""

streamlit run src/tools/sft_data_visualizer.py \
    --server.port ${STREAMLIT_PORT} \
    --server.address 0.0.0.0 \
    --server.enableCORS false \
    --server.enableXsrfProtection false \
    --server.headless true

# При выходе останавливаем vLLM
trap "info 'Останавливаем сервер...'; kill ${VLLM_PID} 2>/dev/null" EXIT
