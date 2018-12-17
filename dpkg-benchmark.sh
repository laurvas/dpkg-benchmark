#!/bin/bash

set -o errexit -o nounset -o pipefail

MP=./mp
PREPARED_ARCHIVE_NAME=dpkg-benchmark
PACKAGES="openbox devscripts build-essential"
LOGFILE_BASE="dpkg-benchmark"
RUNS_NUM=5


usage() {
    echo "Usage: $(basename $0) <archived_container> <device>"
    echo "<archived_container> should be in tar.xz format"
    exit 1
}


generate_variants() {
    run=0
    while ((run < RUNS_NUM)); do
        for j in journal writeback ordered no_journal; do
            for b in barrier nobarrier; do
                for t in eatmydata unsafeio normal; do
                    if [[ $j = no_journal ]]; then
                        echo "$j,$b,*,$t"
                    else
                        for c in 5 30 300; do
                            echo "$j,$b,$c,$t"
                        done
                    fi
                done
            done
        done
        ((run+=1))
    done
}


prepare_archive() {
    mkdir -p $MP
    tar xpf $ARCHIVE -C $MP --numeric-owner
    linux32 systemd-nspawn --quiet -D $MP /usr/bin/apt-get update
    linux32 systemd-nspawn --quiet -D $MP /usr/bin/apt-get -y install eatmydata
    linux32 systemd-nspawn --quiet -D $MP /usr/bin/apt-get -y install --download-only $PACKAGES
    (cd $MP && tar cpJf ../$PREPARED_ARCHIVE_NAME.tar.xz --one-file-system .)
    rm -rf $MP
}


mkfs_and_mount() {
    local journal=$(echo $1 | cut -f1 -d',')
    local barrier=$(echo $1 | cut -f2 -d',')
    local commit=$(echo $1 | cut -f3 -d',')

    if [[ $journal = no_journal ]]; then
        mkfs.ext4 -q -F -m 1 -O ^has_journal $DEV >/dev/null
    else
        mkfs.ext4 -q -F -m 1 $DEV >/dev/null
    fi

    # check trim support
    dgran=$(lsblk -D -o DISC-GRAN --noheadings $DEV)
    dmax=$(lsblk -D -o DISC-MAX --noheadings $DEV)
    if [[ $dgran =~ 0B && $dmax =~ 0B ]]; then
        discard=
    else
        discard=",discard"
    fi

    mkdir -p $MP
    if [[ $journal = writeback || $journal = ordered || $journal = journal ]]; then
        mount $DEV -t ext4 -o data=$journal,$barrier,commit=$commit$discard $MP
    else
        mount $DEV -t ext4 -o $barrier$discard $MP
    fi
}


setup() {
    tar xpf $PREPARED_ARCHIVE_NAME.tar.xz -C $MP --numeric-owner
    booster=$(echo $1 | cut -f4 -d',')
    if [[ $booster = unsafeio ]]; then
        echo "force-unsafe-io" > $MP/etc/dpkg/dpkg.cfg.d/unsafeio
    fi
}


run() {
    booster=$(echo $1 | cut -f4 -d',')
    if [[ $booster = eatmydata ]]; then
        time=$(linux32 systemd-nspawn --quiet -D $MP /bin/bash -c \
        "time eatmydata apt-get -y install $PACKAGES >/dev/null 2>&1" 2>&1)
    else
        time=$(linux32 systemd-nspawn --quiet -D $MP /bin/bash -c \
        "time apt-get -y install $PACKAGES >/dev/null 2>&1" 2>&1)
    fi
    # for an unknown reason the string endings are CR;LF instead of LF
    # simple convert using 'tr'
    echo "$time" | tr -d '\r'
}


umount_and_discard() {
    umount $MP
    # check for trim support
    dgran=$(lsblk -D -o DISC-GRAN --noheadings $DEV)
    dmax=$(lsblk -D -o DISC-MAX --noheadings $DEV)
    if ! [[ $dgran =~ 0B && $dmax =~ 0B ]]; then
        blkdiscard $DEV
    fi
}


seconds_only() {
    minutes=$(echo $1 | sed 's/^\([[:digit:]]\+\)m.*/\1/')
    seconds=$(echo $1 | sed 's/^[[:digit:]]\+m\([[:digit:]]\+\.[[:digit:]]\+\)s/\1/')
    echo "$minutes * 60 + $seconds" | bc
}


test $# -eq 2 || usage
ARCHIVE=$1
DEV=$2
if ! [[ $ARCHIVE =~ \.tar\.xz$ ]]; then
    echo "<archived_container> should be in tar.xz format"
    exit 1
fi
if ! [[ -f $ARCHIVE ]]; then
    echo "$ARCHIVE is not a file"
    exit 1
fi
if ! [[ -b $DEV ]]; then
    echo "<device> should be a block device"
    exit 1
fi

tasks=$(generate_variants | shuf)
tasks_num=$(echo "$tasks" | wc -l)
test -f $PREPARED_ARCHIVE_NAME.tar.xz || prepare_archive
log="$LOGFILE_BASE.${DEV#/dev/}.log"
: > "$log"

i=0
for variant in $tasks; do
    ((i+=1))
    echo -e "\e[1m$i/$tasks_num $variant\e[0m"
    mkfs_and_mount $variant
    setup $variant
    sync
    time=$(run $variant)
    umount_and_discard

    real=$(echo "$time" | awk '/^real/ {print $2}')
    user=$(echo "$time" | awk '/^user/ {print $2}')
    sys=$( echo "$time" | awk '/^sys/  {print $2}')
    echo "$real $user $sys"

    real=$(seconds_only $real)
    user=$(seconds_only $user)
    sys=$(seconds_only $sys)
    echo "$real $user $sys $variant" >> "$log"
done
