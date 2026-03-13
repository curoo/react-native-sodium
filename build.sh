#!/bin/bash

sigfile=`ls -1 libsodium-*.tar.gz.sig`
srcfile=`basename $sigfile .sig`
srcdir=`basename $srcfile .tar.gz`

# --------------------------
# Download and verify source
# --------------------------
[ -f $srcfile ] && rm -f $srcfile
curl https://download.libsodium.org/libsodium/releases/$srcfile > $srcfile
gpg --no-default-keyring --keyring `pwd`/trusted.gpg --verify $sigfile $srcfile || exit 1

# --------------------------
# Extract sources
# --------------------------
[ -e $srcdir ] && rm -Rf $srcdir
tar -xzf $srcfile
cd $srcdir

targetPlatforms="$@"
[ "$targetPlatforms" ] || targetPlatforms="arm x86 ios"
androidPageSizeLDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
originalLDFLAGS="$LDFLAGS"

for targetPlatform in $targetPlatforms
do
  # --------------------------
  # iOS build
  # --------------------------
  platform=`uname`
  if [ "$platform" == 'Darwin' ] && [ "$targetPlatform" == 'ios' ]; then
    IOS_VERSION_MIN=6.0 dist-build/ios.sh
  fi

  # --------------------------
  # Android build
  # --------------------------
  case $targetPlatform in
    "arm")
      LDFLAGS="$originalLDFLAGS $androidPageSizeLDFLAGS" dist-build/android-arm.sh
      LDFLAGS="$originalLDFLAGS $androidPageSizeLDFLAGS" dist-build/android-armv7-a.sh
      LDFLAGS="$originalLDFLAGS $androidPageSizeLDFLAGS" dist-build/android-armv8-a.sh
      ;;
    "x86")
      LDFLAGS="$originalLDFLAGS $androidPageSizeLDFLAGS" dist-build/android-x86.sh
      LDFLAGS="$originalLDFLAGS $androidPageSizeLDFLAGS" dist-build/android-x86_64.sh
    ;;
  esac

done
cd ..


# --------------------------
# Move compiled libraries
# --------------------------
mkdir -p libsodium
rm -Rf libsodium/*

[ -e $srcdir/libsodium-android-* ] && mv $srcdir/libsodium-android-* libsodium/
if [ "$platform" == 'Darwin' ] && [ -e $srcdir/libsodium-ios ]; then
  mv $srcdir/libsodium-ios libsodium/
fi


# --------------------------
# Cleanup
# --------------------------
[ -e $srcdir ] && rm -Rf $srcdir
[ -e $srcfile ] && rm $srcfile
