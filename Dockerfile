FROM python:3.12-slim AS builder
WORKDIR /build
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
ARG LAB_LOGIN
ARG LAB_TOKEN

LABEL org.lab.login="${LAB_LOGIN}" \
 org.lab.token="${LAB_TOKEN}"

ENV PATH="/opt/venv/bin:$PATH" \
 PYTHONDONTWRITEBYTECODE=1 \
 PYTHONUNBUFFERED=1 \
 ROCKET_SIZE=default

RUN useradd -U -s /sbin/nologin --no-create-home nuser
COPY --from=builder /opt/venv /opt/venv
COPY --chown=nuser:nuser app ./app

USER nuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
 CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["python", "-m", "app.app"]