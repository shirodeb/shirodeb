# Dockerfile for ShiroDEB

# Use Deepin V20 as basement
# FROM linuxdeepin/apricot:latest AS base
# Use UOS V20 Eagle as basement
FROM shiroko/uos-eagle:latest AS base
# All your bases are belong to me
LABEL maintainer="hhx.xxm@gmail.com"

FROM base AS depends
# Install necessary dependices for shirodeb
RUN apt-get update && apt-get install -y bash sed dh-make jq git imagemagick inkscape unar curl sudo

FROM depends AS prerequirement
# Add to path
ENV PATH="${PATH}:/shirodeb/bin"
# Setup volumes
VOLUME ["/downloads", "/ingredients", "/artifacts", "/recipe"]
# Workdir
RUN mkdir -p /workdir
WORKDIR /workdir

# Entrypoint and cmd
ENTRYPOINT ["/bin/bash"]
CMD ["/shirodeb/entrypoint.sh", "make_and_save"]

# shirodeb content
FROM prerequirement AS shirodeb
# Add source files
ADD . /shirodeb
# Modify profile
RUN echo "\
    export LOCAL_DOWNLOAD_DIR=\"/downloads\"\
    export DEB_UPLOAD_PATH=\"/artifacts\"\
    export PREFERRED_DOWNLOADER=\"curl\"\
    export INGREDIENTS_DIR=\"/ingredients\"" > /shirodeb/profile
