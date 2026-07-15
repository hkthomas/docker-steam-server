# steam dedicated server for docker.
# https://developer.valvesoftware.com/wiki/SteamCMD#Linux.2FOS_X
# Linux only - Wine support removed

FROM ubuntu:24.04

# ARG WINE_VARIANT=stable

ENV SERVER_DIR=/data/server \
    STEAM=/steam \
    PLATFORM=linux \
    STEAM_APP_ID=0 \
    STEAM_APP_EXTRAS='' \
    STEAM_USERNAME='' \
    STEAM_PASSWORD='' \
    UPDATE_OS=1 \
    UPDATE_STEAM=1 \
    UPDATE_SERVER=1 \
    PUID=1000 \
    PGID=1000 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

COPY source /docker

# Set UTF-8 Locale and install base packages
RUN export LANG=en_US.UTF-8 && \
    export LANGUAGE=en_US.UTF-8 && \
    export LC_ALL=en_US.UTF-8 && \
    export DEBIAN_FRONTEND=noninteractive && \
    export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=true && \
    sed -i -e 's@archive.ubuntu.com@mirrors.ustc.edu.cn@g' -e 's@security.ubuntu.com@mirrors.ustc.edu.cn@g' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get --quiet update && \
    apt-get install --yes --install-recommends 2> /dev/null \
      locales \
      wget \
      gnupg \
      supervisor \
      software-properties-common \
      apt-utils && \
    sed --in-place --expression='s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    /usr/sbin/locale-gen 2> /dev/null && \
    dpkg-reconfigure --frontend=noninteractive locales

# Install Wine based on variant - REMOVED (Linux only)
# RUN export DEBIAN_FRONTEND=noninteractive && \
#     dpkg --add-architecture i386 && \
#     if [ "$WINE_VARIANT" = "stable" ]; then \
#       echo "Installing Ubuntu wine packages..." && \
#       apt-get --quiet update && \
#       apt-get install --yes --install-recommends \
#         lib32gcc-s1 \
#         wine-stable \
#         wine32 \
#         wine64 \
#         winbind \
#         xvfb; \
#     elif [ "$WINE_VARIANT" = "latest" ]; then \
#       echo "Installing WineHQ stable packages..." && \
#       mkdir -pm755 /etc/apt/keyrings && \
#       wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key - && \
#       wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
#       apt-get --quiet update && \
#       apt-get install --yes --install-recommends \
#         libsdl2-2.0-0 \
#         libsdl2-2.0-0:i386 \
#         libc6 \
#         libc6:i386 \
#         lib32gcc-s1 \
#         winehq-stable \
#         winbind \
#         supervisor \
#         xvfb || (apt-get --fix-broken install --yes && apt-get install --yes --install-recommends winehq-stable); \
#     elif [ "$WINE_VARIANT" = "experimental" ]; then \
#       echo "Installing WineHQ staging packages..." && \
#       mkdir -pm755 /etc/apt/keyrings && \
#       wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key - && \
#       wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources && \
#       apt-get --quiet update && \
#       apt-get install --yes --install-recommends \
#         libsdl2-2.0-0 \
#         libsdl2-2.0-0:i386 \
#         libc6 \
#         libc6:i386 \
#         lib32gcc-s1 \
#         winehq-staging \
#         winbind \
#         supervisor \
#         xvfb; \
#     else \
#       echo "Unknown WINE_VARIANT: $WINE_VARIANT" && exit 1; \
#     fi && \
#     apt-get --quiet --yes upgrade

# Install winetricks - REMOVED (Wine tool)
# RUN apt-get install --yes --install-recommends \
#       cabextract \
#       unzip \
#       p7zip && \
#     wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -O /usr/bin/winetricks && \
#     chmod a+x /usr/bin/winetricks

# Auto-accept license and install steamcmd
RUN export DEBIAN_FRONTEND=noninteractive && \
    echo steam steam/license note '' | debconf-set-selections && \
    echo steam steam/question select 'I AGREE' | debconf-set-selections && \
    dpkg --add-architecture i386 && \
    apt-get --quiet update && \
    apt-get --quiet --yes upgrade && \
    apt-get install --yes --install-recommends \
      libsdl2-2.0-0:i386 \
      libsdl2-2.0-0 \
      gdb && \
    apt-get install --yes --install-recommends \
      steamcmd

# Create steam user and setup permissions
RUN useradd --create --home ${STEAM} steam && \
    su - steam -c " \
      cd ${STEAM} && \
      steamcmd +quit" && \
    mkdir -p /steam/.steam/{sdk32,sdk64} && \
    echo "\nexport PATH=\$PATH:/steam/.steam/steamcmd/linux32:/steam/.steam/steamcmd/linux64" | tee -a /steam/.profile && \
    mkdir -p /data && \
    chown -R steam:steam ${STEAM} /data /docker && \
    chmod 0755 /docker/*

# Setup supervisord process control system
RUN cp /docker/supervisord.conf /etc/supervisor/supervisord.conf && \
    mkdir -p /data/supervisord

# Clean up target host system caches
RUN apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rfv /var/lib/{apt,dpkg} /var/lib/{cache,log} /tmp/* /var/tmp/* && \
    mkdir -p /var/lib/dpkg/{alternatives,info,parts,updates} && \
    touch /var/lib/dpkg/status && \
    echo -e 'amd64\ni386' > /var/lib/dpkg/arch

WORKDIR /data

VOLUME /data

ENTRYPOINT ["/docker/startup"]

# For ports required by steam services, see:
# https://support.steampowered.com/kb_article.php?ref=8571-GLVN-8711
# Be sure to include any server-specific ports.
EXPOSE 27015/tcp 27015/udp
