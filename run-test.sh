#!/bin/bash
# ============================================================
# VecGlypher — Быстрый запуск (без установки)
# Использовать после того как install_and_run.sh уже выполнялся
# ============================================================

MODEL_LOCAL="/workspace/VecGlypher/saves/VecGlypher-27b-it"
VLLM_PORT=30000
STREAMLIT_PORT=8443
WORKDIR="/workspace/VecGlypher"

# Активируем conda
source /workspace/miniconda3/etc/profile.d/conda.sh
conda activate svg_glyph_llm_eval

cd ${WORKDIR}

# Запуск vLLM в фоне
echo "🚀 Запускаем vLLM сервер..."
vllm serve ${MODEL_LOCAL} \
    --host 0.0.0.0 \
    --port ${VLLM_PORT} \
    -tp 1 -dp 1 \
    --enable-log-requests \
    > /tmp/vllm_server.log 2>&1 &
VLLM_PID=$!

# Ждём готовности
echo "   Загружаем модель в GPU, ждите..."
for i in $(seq 1 60); do
    sleep 5
    if curl -s http://localhost:${VLLM_PORT}/v1/models > /dev/null 2>&1; then
        echo "✅ vLLM готов! (~$((i*5)) сек)"
        break
    fi
    if ! kill -0 ${VLLM_PID} 2>/dev/null; then
        echo "❌ vLLM упал! Лог: tail -f /tmp/vllm_server.log"
        exit 1
    fi
    echo -ne "   ⏳ $((i*5)) сек...\r"
done

# Запуск Streamlit
echo ""
echo "✅ Открывайте: https://ВАШ_POD_ID-${STREAMLIT_PORT}.proxy.runpod.net"
echo ""
streamlit run src/tools/sft_data_visualizer.py \
    --server.port ${STREAMLIT_PORT} \
    --server.address 0.0.0.0 \
    --server.enableCORS false \
    --server.enableXsrfProtection false \
    --server.headless true

trap "kill ${VLLM_PID} 2>/dev/null" EXIT
