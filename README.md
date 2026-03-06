# VecGlypher на RunPod

VecGlypher — генерация векторных глифов (SVG) с помощью языковой модели. [CVPR'26]

---

## Требования

- RunPod GPU Pod с **96GB+ VRAM** (rtx pro 6000 96GB или аналог)
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


**Посмотреть лог vLLM**
```bash
tail -f /tmp/vllm_server.log
```

**Проверить GPU**
```bash
nvidia-smi
```
