FROM python:3.11-bookworm AS requirements-stage

WORKDIR /tmp

ENV POETRY_HOME="/opt/poetry" PATH="${PATH}:/opt/poetry/bin"

RUN curl -sSL https://install.python-poetry.org | python - -y && \
  poetry self add poetry-plugin-export

COPY ./pyproject.toml ./poetry.lock* /tmp/

RUN poetry export \
      -f requirements.txt \
      --output requirements.txt \
      --without-hashes \
      --without-urls

FROM python:3.11-bookworm AS build-stage

WORKDIR /wheel

COPY --from=requirements-stage /tmp/requirements.txt /wheel/requirements.txt

# RUN python3 -m pip config set global.index-url https://mirrors.aliyun.com/pypi/simple

RUN pip wheel --wheel-dir=/wheel --no-cache-dir --requirement /wheel/requirements.txt

FROM python:3.11-bookworm AS metadata-stage

WORKDIR /tmp

RUN --mount=type=bind,source=./.git/,target=/tmp/.git/ \
  git describe --tags --exact-match > /tmp/VERSION 2>/dev/null \
  || git rev-parse --short HEAD > /tmp/VERSION \
  && echo "Building version: $(cat /tmp/VERSION)"

FROM python:3.11-slim-bookworm

WORKDIR /app/zhenxun

# 2. 环境变量 (按照你的要求添加)
ENV GPG_KEY=A035C8C19219BA821ECEA86B64E628F8D684696D
ENV PYTHON_VERSION=3.11.14
ENV PASSWORD=zr8dV4aYCL67c1N3WsEoHpjAuPbI9520
ENV PYTHON_SHA256=8d3ed8ec5c88c1c95f5e558612a725450d2452813ddad5e58fdb1a53b1209b78
ENV TZ=Asia/Shanghai
ENV PYTHONUNBUFFERED=1
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=C.UTF-8

EXPOSE 8080

# 系统依赖安装
# 1. 完整的 C++ 编译环境: build-essential, cmake
# 原有的依赖: curl, fontconfig, fonts-noto-color-emoji
RUN apt update && \
    apt install -y --no-install-recommends \
    curl \
    fontconfig \
    fonts-noto-color-emoji \
    build-essential \
    cmake \
    git \
    gcc \
    g++ \
    make \
    && apt clean \
    && fc-cache -fv \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖项和应用代码
COPY --from=build-stage /wheel /wheel
COPY . .

# 安装基础依赖 (从 wheel 安装)
RUN pip install --no-cache-dir --no-index --find-links=/wheel -r /wheel/requirements.txt && rm -rf /wheel

# 1. 环境依赖 (额外补充的包)
# 注意：wordcloud 等包需要依赖上面的 build-essential 才能安装成功
RUN pip install --no-cache-dir \
    packaging \
    poetry \
    bilibili-api-python \
    simpleeval \
    tomli_w \
    emoji \
    zhdate \
    cachetools \
    asyncpg \
    chinese_calendar \
    spacy_pkuseg \
    lunardate \
    wordcloud \
    playwright_stealth

# 安装 Playwright 浏览器
# 使用 --with-deps 安装浏览器所需的系统依赖
RUN playwright install --with-deps \
  && rm -rf /var/lib/apt/lists/* /tmp/*

COPY --from=metadata-stage /tmp/VERSION /app/VERSION

# 3. 硬盘挂载
VOLUME ["/app/zhenxun/resources", "/app/zhenxun/log", "/app/zhenxun/data", "/app/zhenxun/zhenxun/plugins"]

CMD ["python", "bot.py"]
