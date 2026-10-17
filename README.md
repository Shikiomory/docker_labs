# Отчет:

## Ссылка на Docker Hub: (https://hub.docker.com/r/shikomory/image-lab/tags)

## 1. Преимущества:
1. **Многоэтапная сборка (Multi-stage build) и минимизация размера**  
   Установка библиотек вынесена в промежуточный этап `builder`, а в финальный образ переносится только папка `/opt/venv`. Это отсекает кэш pip и временные сборочные файлы, сохраняя общий размер образа в пределах 135 MB (в Docker Hub сжатый размер составляет 46.53 MB).
   ```dockerfile
   COPY --from=builder /opt/venv /opt/venv
   ```

2. **Оптимизация кэширования слоев Docker**  
   Файл `requirements.txt` копируется и устанавливается до переноса исходного кода приложения. При любых изменениях логики в директории `app/` слой зависимостей переиспользуется из кэша, сокращая повторную сборку до считанных секунд.
   ```dockerfile
   COPY requirements.txt .
   RUN pip install --no-cache-dir -r requirements.txt
   COPY --chown=nuser:nuser app ./app
   ```

3. **Отказ от root-привилегий (безопасность)**  
Создан системный пользователь nuser без лишних прав и домашней папки, а директива USER nuser переключает контейнер на него, защищая систему от запуска из-под администратора (root). Флаг --chown=nuser:nuser при копировании сразу назначает владельца файлов, не создавая лишних промежуточных слоев и экономя место.
   ```dockerfile
   RUN useradd -U -s /sbin/nologin --no-create-home nuser
   COPY --chown=nuser:nuser app ./app
   USER nuser
   ```

4. **Совместимость с режимом `--read-only` (только чтение)**  
   Параметр `PYTHONDONTWRITEBYTECODE=1` запрещает Python компилировать байт-код на диск в папки `__pycache__`, благодаря чему сервис стабильно работает при монтировании файловой системы только для чтения. Флаг `PYTHONUNBUFFERED=1` отключает задержку буферизации логов, транслируя stdout/stderr напрямую в консоль контейнера.
   ```dockerfile
   ENV PYTHONDONTWRITEBYTECODE=1 \
       PYTHONUNBUFFERED=1
   ```

5. **Корректная обработка сигнала SIGTERM**  
   Команда запуска оформлена в exec-формате (JSON-массив), благодаря чему процесс Python становится процессом PID 1 в обход командной оболочки `/bin/sh`. Сервер моментально перехватывает сигнал остановки `docker stop`, завершая работу за доли секунды без 10-секундного зависания и принудительного `SIGKILL`.
   ```dockerfile
   CMD ["python", "-m", "app.app"]
   ```

6. **Встроенный HEALTHCHECK без утяжеления образа**  
   Чтобы Docker проверял, жив ли наш сервис, мы опрашиваем адрес /health встроенной в Python библиотекой urllib.request. Это избавляет от необходимости ставить сторонние утилиты вроде curl или wget: образ не раздувается в размере, а в системе нет лишних программ, через которые контейнер могли бы взломать.
   ```dockerfile
   HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
     CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
   ```

7. **Динамическая конфигурация и персонализация**  
   Конфигурационный параметр `ROCKET_SIZE` задан переменной по умолчанию и может быть переопределен при старте контейнера (`-e ROCKET_SIZE=Big`) без пересборки слоев. Метаданные логин и токен зафиксированы через директиву `LABEL`.
   ```dockerfile
   ARG LAB_LOGIN
   ARG LAB_TOKEN
   LABEL org.lab.login="${LAB_LOGIN}" \
         org.lab.token="${LAB_TOKEN}"
   ENV ROCKET_SIZE=default
   ```
   
## 2. История слоев образа (`docker history`)

Вывод команды `docker history shikomory/image-lab:d22f8c27`:

```text
IMAGE          CREATED             CREATED BY                                      SIZE      COMMENT
0cf059c82665   About an hour ago   CMD ["python" "-m" "app.app"]                   0B        buildkit.dockerfile.v0
<missing>      About an hour ago   HEALTHCHECK &{["CMD-SHELL" "python -c \"impo…   0B        buildkit.dockerfile.v0
<missing>      About an hour ago   USER nuser                                      0B        buildkit.dockerfile.v0
<missing>      About an hour ago   COPY --chown=nuser:nuser app ./app # buildkit   1.06kB    buildkit.dockerfile.v0
<missing>      About an hour ago   COPY /opt/venv /opt/venv # buildkit             15.9MB    buildkit.dockerfile.v0
<missing>      About an hour ago   RUN |2 LAB_LOGIN=shikomory LAB_TOKEN=d22f8c2…   4.36kB    buildkit.dockerfile.v0
<missing>      About an hour ago   ENV PATH=/opt/venv/bin:/usr/local/bin:/usr/l…   0B        buildkit.dockerfile.v0
<missing>      About an hour ago   LABEL org.lab.login=shikomory org.lab.token=…   0B        buildkit.dockerfile.v0
<missing>      About an hour ago   ARG LAB_TOKEN=d22f8c27b49d4f94c3f3bb4b84e716…   0B        buildkit.dockerfile.v0
<missing>      About an hour ago   ARG LAB_LOGIN=shikomory                         0B        buildkit.dockerfile.v0
<missing>      About an hour ago   WORKDIR /app                                    0B        buildkit.dockerfile.v0
<missing>      11 days ago         CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      11 days ago         RUN /bin/sh -c set -eux;  for src in idle3 p…   36B       buildkit.dockerfile.v0
<missing>      11 days ago         RUN /bin/sh -c set -eux;   savedAptMark="$(a…   36.8MB    buildkit.dockerfile.v0
<missing>      11 days ago         ENV PYTHON_SHA256=c2c4321961fab0fb999d66e0ce…   0B        buildkit.dockerfile.v0
<missing>      11 days ago         ENV PYTHON_VERSION=3.12.15                      0B        buildkit.dockerfile.v0
<missing>      11 days ago         ENV GPG_KEY=7169605F62C751356D054A26A821E680…   0B        buildkit.dockerfile.v0
<missing>      11 days ago         RUN /bin/sh -c set -eux;  apt-get update;  a…   3.81MB    buildkit.dockerfile.v0
<missing>      11 days ago         ENV LANG=C.UTF-8                                0B        buildkit.dockerfile.v0
<missing>      11 days ago         ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
<missing>      12 days ago         # debian.sh --arch 'amd64' out/ 'trixie' '@1…   78.8MB    debuerreotype 0.17
```

