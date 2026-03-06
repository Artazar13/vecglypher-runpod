# VecGlypher на RunPod

VecGlypher — генерация векторных глифов (SVG) с помощью языковой модели. [CVPR'26]

---

## Требования

- RunPod GPU Pod с **96GB+ VRAM** (H100 96GB или аналог)
- CUDA 12.8
- Открытые порты в настройках Pod: **8443** и **30000**
- Токен HuggingFace: https://huggingface.co/settings/tokens

---

## Быстрый старт (рекомендуется)

Скопируйте `install_and_run.sh` на Pod и выполните:

```bash
chmod +x install_and_run.sh
./install_and_run.sh
```

Скрипт сам:
1. Спросит ваш HuggingFace токен (один раз)
2. Установит Miniconda и создаст окружение
3. Установит все зависимости включая flash-attn без компиляции
4. Скачает веса модели (~50GB)
5. Запустит vLLM сервер
6. Запустит Streamlit интерфейс

После запуска откройте в браузере:
```
https://ВАШ_POD_ID-8443.proxy.runpod.net
```

**При повторном запуске** скрипт пропустит уже выполненные шаги и сразу запустит приложение.

---

## Ручной запуск (по шагам)

Если хотите контролировать каждый шаг — откройте **два терминала**.

### Терминал 1 — vLLM сервер

```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate svg_glyph_llm_eval
cd /workspace/VecGlypher

vllm serve saves/VecGlypher-27b-it \
    --host 0.0.0.0 \
    --port 30000 \
    -tp 1 -dp 1 \
    --enable-log-requests
```

Ждите сообщения `Application startup complete.`

### Терминал 2 — Streamlit

```bash
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate svg_glyph_llm_eval
cd /workspace/VecGlypher

streamlit run src/tools/sft_data_visualizer.py --server.port 8443
```

Откройте: `https://ВАШ_POD_ID-8443.proxy.runpod.net`

---

## Структура файлов

```
/workspace/VecGlypher/
├── install_and_run.sh       # Установка + запуск одной командой
├── saves/
│   └── VecGlypher-27b-it/   # Веса модели (~50GB)
├── outputs/                 # Сгенерированные глифы
├── hf_cache/                # Кэш HuggingFace
└── .env                     # Токен (права 600, только для вас)
```

---

## Решение проблем

**`conda: command not found`**
```bash
source /opt/miniconda3/etc/profile.d/conda.sh
```

**vLLM не запускается — недостаточно VRAM**
Модель 27B требует минимум 90GB VRAM.

**Посмотреть лог vLLM**
```bash
tail -f /tmp/vllm_server.log
```

**Проверить GPU**
```bash
nvidia-smi
```
