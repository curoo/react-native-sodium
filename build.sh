#!/bin/bash
set -euo pipefail

LIBSODIUM_VERSION="${LIBSODIUM_VERSION:-1.0.20}"
LIBSODIUM_RELEASE_URLS=(
  "https://download.libsodium.org/libsodium/releases"
  "https://download.libsodium.org/libsodium/releases/old/unsupported"
)

sigfile=""
for candidateSigfile in libsodium-*.tar.gz.sig
do
  if [ -f "$candidateSigfile" ]; then
    sigfile="$candidateSigfile"
    break
  fi
done
if [ -z "$sigfile" ]; then
  sigfile="libsodium-$LIBSODIUM_VERSION.tar.gz.sig"
fi
srcfile=`basename $sigfile .sig`
srcdir=`basename $srcfile .tar.gz`

# --------------------------
# Download and verify source
# --------------------------
[ -f $srcfile ] && rm -f $srcfile
[ -f $sigfile ] && rm -f $sigfile

for releaseUrl in "${LIBSODIUM_RELEASE_URLS[@]}"
do
  if curl -fL --silent "$releaseUrl/$sigfile" -o "$sigfile" && curl -fL --silent "$releaseUrl/$srcfile" -o "$srcfile"; then
    break
  fi
  rm -f "$sigfile" "$srcfile"
done

if [ ! -f "$sigfile" ] || [ ! -f "$srcfile" ]; then
  echo "Unable to download $srcfile and $sigfile from libsodium release URLs" >&2
  exit 1
fi

gpg --no-default-keyring --keyring `pwd`/trusted.gpg --verify $sigfile $srcfile || exit 1

# --------------------------
# Extract sources
# --------------------------
srcdir=`tar -tzf $srcfile | head -n 1 | cut -d/ -f1`
[ -e $srcdir ] && rm -Rf $srcdir
tar -xzf $srcfile
cd $srcdir

targetPlatforms="$@"
[ "$targetPlatforms" ] || targetPlatforms="arm x86 ios"

# The JNI bridge exposes crypto_pwhash_scryptsalsa208sha256 symbols. libsodium's
# Android minimal build excludes those headers/symbols in newer releases.
export LIBSODIUM_FULL_BUILD="${LIBSODIUM_FULL_BUILD:-1}"

androidPageSizeLDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
originalLDFLAGS="${LDFLAGS:-}"
androidToolchainBin="${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/$(uname | tr '[:upper:]' '[:lower:]')-x86_64/bin"

run_android_build() {
  local buildScript="$1"
  AR="$androidToolchainBin/llvm-ar" \
    RANLIB="$androidToolchainBin/llvm-ranlib" \
    STRIP="$androidToolchainBin/llvm-strip" \
    LDFLAGS="$originalLDFLAGS $androidPageSizeLDFLAGS" \
    "$buildScript"
}

# Some libsodium dist-build/android-*.sh scripts overwrite LDFLAGS instead of
# preserving inherited values. Patch them after extraction so every generated
# Android shared object, including x86/x86_64, is linked with 16 KB-compatible
# PT_LOAD segment alignment.
for androidBuildScript in dist-build/android-*.sh
do
  [ -f "$androidBuildScript" ] || continue
  PAGE_SIZE_LDFLAGS="$androidPageSizeLDFLAGS" perl -0pi -e '
    s/^export LDFLAGS="([^"]*)"/export LDFLAGS="\${LDFLAGS:-} $1"/mg;
    if ($_ !~ /^export LDFLAGS=/m) {
      s/^(.*android-build\.sh.*)$/export LDFLAGS="\${LDFLAGS:-} $ENV{PAGE_SIZE_LDFLAGS}"\n$1/m;
    }
  ' "$androidBuildScript"
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
      # libsodium 1.0.20 no longer ships android-arm.sh/armv6. React Native's
      # default Android ABIs are armeabi-v7a, arm64-v8a, x86 and x86_64, so
      # armv6 is not needed for the Expo app or Play Store uploads.
      run_android_build dist-build/android-armv7-a.sh
      run_android_build dist-build/android-armv8-a.sh
      ;;
    "x86")
      run_android_build dist-build/android-x86.sh
      run_android_build dist-build/android-x86_64.sh
    ;;
  esac

done
cd ..


# --------------------------
# Move compiled libraries
# --------------------------
mkdir -p libsodium/build
rm -Rf libsodium/build/libsodium-android-*

for androidArtifact in $srcdir/libsodium-android-*
do
  [ -e "$androidArtifact" ] || continue
  mv "$androidArtifact" libsodium/build/
done
if [ "$platform" == 'Darwin' ] && [ -e $srcdir/libsodium-ios ]; then
  rm -Rf libsodium/libsodium-ios
  mv $srcdir/libsodium-ios libsodium/
fi


# --------------------------
# Cleanup
# --------------------------
[ -e $srcdir ] && rm -Rf $srcdir
[ -e $srcfile ] && rm $srcfile
[ -e $sigfile ] && rm $sigfile
