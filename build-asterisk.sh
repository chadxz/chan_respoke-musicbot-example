#!/bin/bash

PROGNAME=$(basename $0)

if test -z ${ASTERISK_VERSION}; then
    echo "${PROGNAME}: ASTERISK_VERSION requires" >&2
    exit 1
fi

# 1.5 jobs per core works out okay
: ${JOBS:=$(( $(nproc) + $(nproc) / 2 ))}

set -ex

# download the asterisk-opus patches
mkdir -p /usr/src/asterisk-opus
cd /usr/src/asterisk-opus
curl -vsL https://api.github.com/repos/seanbright/asterisk-opus/tarball/dc5ff5fb4b42bbd8884688678ec3d8e9751cbb18 |
    tar --strip-components 1 -xz

# download the asterisk source
mkdir -p /usr/src/asterisk
cd /usr/src/asterisk
curl -vsL http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz |
    tar --strip-components 1 -xz

# patch asterisk to work with opus
cp /usr/src/asterisk-opus/codecs/* codecs/
cp /usr/src/asterisk-opus/formats/* formats/
patch -p1 < /usr/src/asterisk-opus/asterisk.patch

./configure
make menuselect/menuselect menuselect-tree menuselect.makeopts

# enable opus and vp8
menuselect/menuselect --enable codec_opus menuselect.makeopts
menuselect/menuselect --enable format_vp8 menuselect.makeopts

# MOAR SOUNDS
for i in CORE-SOUNDS-EN MOH-OPSOUND EXTRA-SOUNDS-EN; do
    for j in ULAW ALAW G722 GSM SLN16; do
        menuselect/menuselect --enable $i-$j menuselect.makeopts
    done
done

make -j ${JOBS} all
make install
chown -R asterisk:asterisk /var/*/asterisk
chmod -R 750 /var/spool/asterisk
mkdir -p /etc/asterisk/
cp /usr/src/asterisk/configs/basic-pbx/*.conf /etc/asterisk/

# Set runuser and rungroup
sed -i -E 's/^;(run)(user|group)/\1\2/' /etc/asterisk/asterisk.conf

cd /
rm -rf /usr/src/asterisk
exec rm -rf /usr/src/asterisk-opus
