# ============================================================
# Builder
# ============================================================
FROM debian:bookworm-slim AS builder

ARG HPLIP_VERSION=v3.26.4

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    lsb-release \
    pkg-config \
    g++ \
    make \
    gawk \
    python-is-python3 \
    python3-dev \
    libssl-dev \
    avahi-utils \
    libavahi-core-dev \
    libavahi-client-dev \
    libavahi-common-dev \
    libjpeg62-turbo-dev \
    libtool \
    libtool-bin \
    libcups2-dev \
    libcupsimage2-dev \
    libusb-1.0.0-dev \
    libdbus-1-dev \
    libsnmp-dev \
    snmp \
    cups \
    cups-bsd \
    cups-client \
    cups-filters \
    foomatic-db-compressed-ppds \
    printer-driver-all \
    openprinting-ppds \
 && rm -rf /var/lib/apt/lists/*

RUN cd /tmp \
 && curl -fL \
      "https://api.github.com/repos/arembez/hplip/tarball/refs/tags/${HPLIP_VERSION}" \
      -o hplip.tar.gz \
 && tar -xzf hplip.tar.gz \
 && cd arembez-hplip-*/hplip-*-sources \
 && ./configure \
      --with-hpppddir=/usr/share/ppd/HP \
      --libdir=/usr/lib/x86_64-linux-gnu \
      --prefix=/usr \
      --enable-network-build \
      --disable-scan-build \
      --disable-fax-build \
      --disable-dbus-build \
      --disable-qt4 \
      --disable-qt5 \
      --disable-class-driver \
      --disable-doc-build \
      --disable-policykit \
      --disable-libusb01_build \
      --disable-udev_sysfs_rules \
      --enable-hpcups-install \
      --disable-hpijs-install \
      --disable-foomatic-ppd-install \
      --disable-foomatic-drv-install \
      --disable-cups-ppd-install \
      --enable-cups-drv-install \
      CPPFLAGS="-I/usr/include/dbus-1.0 -I/usr/lib/x86_64-linux-gnu/dbus-1.0/include" \
 && make -j"$(nproc)" \
 && make install DESTDIR=/opt/hplip-install

RUN find /opt/hplip-install -name '*.a' -delete \
 && find /opt/hplip-install -name '*.la' -delete


# ============================================================
# Runtime
# ============================================================
FROM debian:bookworm-slim AS runtime

ENV ADMIN_PASSWORD=admin

RUN apt-get update \
 && apt-get install -y \
    sudo \
    cups \
    cups-bsd \
    cups-client \
    cups-filters \
    foomatic-db-compressed-ppds \
    printer-driver-all \
    openprinting-ppds \
    libjpeg62-turbo \
    libusb-1.0-0 \
    libsnmp40 \
    libavahi-client3 \
    libavahi-common3 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/hplip-install/ /

RUN adduser \
      --home /home/admin \
      --shell /bin/bash \
      --gecos "admin" \
      --disabled-password admin \
 && adduser admin sudo \
 && adduser admin lp \
 && adduser admin lpadmin

RUN echo 'admin ALL=(ALL) NOPASSWD:ALL' \
    > /etc/sudoers.d/admin \
 && chmod 0440 /etc/sudoers.d/admin

RUN /usr/sbin/cupsd \
 && while [ ! -f /var/run/cups/cupsd.pid ]; do sleep 1; done \
 && cupsctl --remote-admin --remote-any --share-printers \
 && kill "$(cat /var/run/cups/cupsd.pid)" \
 && echo "ServerAlias *" >> /etc/cups/cupsd.conf

RUN cp -rp /etc/cups /etc/cups-skel

RUN rm -rf \
    /usr/share/man/* \
    /usr/share/doc/* \
    /usr/share/info/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["cupsd", "-f"]

VOLUME ["/etc/cups"]

EXPOSE 631
