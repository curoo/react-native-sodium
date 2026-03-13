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
buildIOS=0

for targetPlatform in $targetPlatforms
do
  if [ "$targetPlatform" == "ios" ]; then
    buildIOS=1
  fi
done

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
rm -Rf libsodium/libsodium-android-*
rm -Rf libsodium/build/libsodium-android-*

if [ "$buildIOS" == "1" ]; then
  rm -Rf libsodium/libsodium-ios
  rm -Rf libsodium/build/libsodium-apple
fi

[ -e $srcdir/libsodium-android-* ] && mv $srcdir/libsodium-android-* libsodium/
[ -e $srcdir/build/libsodium-android-* ] && mkdir -p libsodium/build && mv $srcdir/build/libsodium-android-* libsodium/build/
if [ "$platform" == 'Darwin' ] && [ -e $srcdir/libsodium-ios ]; then
  mv $srcdir/libsodium-ios libsodium/
fi
if [ "$platform" == 'Darwin' ] && [ -e $srcdir/build/libsodium-apple ]; then
  mkdir -p libsodium/build
  mv $srcdir/build/libsodium-apple libsodium/build/
fi


# --------------------------
# Cleanup
# --------------------------
[ -e $srcdir ] && rm -Rf $srcdir
[ -e $srcfile ] && rm $srcfile
