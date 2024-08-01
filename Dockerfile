FROM python:3.11-slim AS builder

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    openssl

# Upgrade pip
RUN pip install --upgrade pip

# Install python packages from requirements.txt
COPY requirements.txt .
RUN pip install --prefix /install --no-warn-script-location --no-cache-dir -r requirements.txt

FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    tor \
    curl \
    libstdc++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add user and config directory
ARG DOCKER_USER=whoogle
ARG DOCKER_USERID=927
ARG config_dir=/config
RUN mkdir -p $config_dir && chmod a+w $config_dir
VOLUME $config_dir

# Environment variables
ARG url_prefix=''
ARG username=''
ARG password=''
ARG proxyuser=''
ARG proxypass=''
ARG proxytype=''
ARG proxyloc=''
ARG whoogle_dotenv=''
ARG use_https=''
ARG whoogle_port=5000
ARG twitter_alt='farside.link/nitter'
ARG youtube_alt='farside.link/invidious'
ARG reddit_alt='farside.link/libreddit'
ARG medium_alt='farside.link/scribe'
ARG translate_alt='farside.link/lingva'
ARG imgur_alt='farside.link/rimgo'
ARG wikipedia_alt='farside.link/wikiless'
ARG imdb_alt='farside.link/libremdb'
ARG quora_alt='farside.link/quetre'

ENV CONFIG_VOLUME=$config_dir \
    WHOOGLE_URL_PREFIX=$url_prefix \
    WHOOGLE_USER=$username \
    WHOOGLE_PASS=$password \
    WHOOGLE_PROXY_USER=$proxyuser \
    WHOOGLE_PROXY_PASS=$proxypass \
    WHOOGLE_PROXY_TYPE=$proxytype \
    WHOOGLE_PROXY_LOC=$proxyloc \
    WHOOGLE_DOTENV=$whoogle_dotenv \
    HTTPS_ONLY=$use_https \
    EXPOSE_PORT=$whoogle_port \
    WHOOGLE_ALT_TW=$twitter_alt \
    WHOOGLE_ALT_YT=$youtube_alt \
    WHOOGLE_ALT_RD=$reddit_alt \
    WHOOGLE_ALT_MD=$medium_alt \
    WHOOGLE_ALT_TL=$translate_alt \
    WHOOGLE_ALT_IMG=$imgur_alt \
    WHOOGLE_ALT_WIKI=$wikipedia_alt \
    WHOOGLE_ALT_IMDB=$imdb_alt \
    WHOOGLE_ALT_QUORA=$quora_alt

WORKDIR /whoogle

# Copy built packages
COPY --from=builder /install /usr/local
COPY misc/tor/torrc /etc/tor/torrc
COPY misc/tor/start-tor.sh misc/tor/start-tor.sh
COPY app/ app/
COPY run whoogle.env* ./

# Create user/group to run as
RUN adduser --disabled-password --gecos "" $DOCKER_USER

# Fix ownership / permissions
RUN chown -R ${DOCKER_USER}:${DOCKER_USER} /whoogle /var/lib/tor

# Allow writing symlinks to build dir
RUN chown $DOCKER_USERID:$DOCKER_USERID app/static/build

USER $DOCKER_USER:$DOCKER_USER

EXPOSE $EXPOSE_PORT

HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -f http://localhost:${EXPOSE_PORT}/healthz || exit 1

CMD misc/tor/start-tor.sh & ./run
