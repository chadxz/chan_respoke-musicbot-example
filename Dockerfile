FROM respoke/pjsip:latest
MAINTAINER Respoke <info@respoke.io>

RUN useradd --system asterisk

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
            build-essential \
            curl \
            libcurl4-openssl-dev \
            libedit-dev \
            libgsm1-dev \
            libjansson-dev \
            libogg-dev \
            libsqlite3-dev \
            libsrtp0-dev \
            libssl-dev \
            libxml2-dev \
            libxslt1-dev \
            uuid \
            uuid-dev \
            binutils-dev \
            libpopt-dev \
            libspandsp-dev \
            libvorbis-dev \
            portaudio19-dev \
            python-pip \
            && \
    pip install j2cli && \
    apt-get purge -y --auto-remove && rm -rf /var/lib/apt/lists/*

# Download and build opus
ENV OPUS_VERSION=1.1.2
RUN mkdir -p /usr/src/opus && \
    cd /usr/src/opus && \
    curl -vsL http://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz | \
      tar --strip-components 1 -xz && \
    ./configure && \
    make all install && \
    /sbin/ldconfig && \
    cd / && \
    rm -rf /usr/src/opus

# Download and build asterisk with the opus patch
ENV ASTERISK_VERSION=13.6.0
COPY build-asterisk.sh /build-asterisk
RUN /build-asterisk && rm -f /build-asterisk

# Download and build chan_respoke
ENV CHAN_RESPOKE_VERSION=v1.1.0-7-ga17a16d
RUN mkdir -p /usr/src/chan_respoke && \
    cd /usr/src/chan_respoke && \
    curl -vsL https://api.github.com/repos/respoke/chan_respoke/tarball/a17a16df6c9c9268cdf429fea34247c4f461927d | \
      tar --strip-components 1 -xz && \
    make all install && \
    install -m 644 example/sounds/respoke* /var/lib/asterisk/sounds/ && \
    sed 's#^;dtls_cert_file=.*$#dtls_cert_file=/etc/asterisk/keys/respoke.pem#' respoke.conf.sample > /etc/asterisk/respoke.conf && \
    rm -rf /usr/src/chan_respoke

COPY conf/ /etc/asterisk/
COPY docker-entrypoint.sh /
RUN echo "#include modules-respoke.conf" >> /etc/asterisk/modules.conf
RUN echo "load = func_channel.so" >> /etc/asterisk/modules.conf
CMD ["/usr/sbin/asterisk", "-f"]
ENTRYPOINT ["/docker-entrypoint.sh"]
