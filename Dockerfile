# Dockerfile for ShiroDEB
# Use Deepin V20 as basement
FROM linuxdeepin/apricot:latest
# All your bases are belong to me
LABEL maintainer="hhx.xxm@gmail.com"
# Install necessary dependices for shirodeb
RUN apt-get update && apt-get install -y bash sed dh-make jq git imagemagick inkscape unar curl
# Add source files
ADD . /shirodeb
# Add to path
ENV PATH="${PATH}:/shirodeb/bin"
# Setup volumes
VOLUME ["/downloads", "/ingredients", "/artifacts", "/recipe"]
# Modify profile
RUN echo "\
    export LOCAL_DOWNLOAD_DIR=\"/downloads\"\
    export DEB_UPLOAD_PATH=\"/artifacts\"\
    export PREFERRED_DOWNLOADER=\"curl\"\
    export INGREDIENTS_DIR=\"/ingredients\"" > /shirodeb/profile
# Workdir
WORKDIR /recipe
# Entrypoint and cmd
ENTRYPOINT ["/shirodeb/bin/shirodeb"]
CMD ["make_and_save"]
