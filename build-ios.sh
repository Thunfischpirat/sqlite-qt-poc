#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Keep the tools and npm cache separate from other projects on the Mac.
tools="${SQLITE_POC_TOOLS:-$HOME/Christian/sqlite-poc-tools}"
qt="$tools/Qt/6.12.0/ios-simulator-arm64"
export npm_config_cache="$tools/npm-cache"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export PATH="$tools/venv-python313/bin:$PATH"

if [[ ! -x "$qt/bin/qt-cmake" ]]; then
    echo "Qt for the ARM64 iOS simulator is missing. See the README setup steps."
    exit 1
fi
for command in node npm cmake ninja; do
    command -v "$command" >/dev/null || { echo "Missing prerequisite: $command"; exit 1; }
done
if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) === 24 ? 0 : 1)'; then
    echo 'Use Node 24 LTS before running this script: nvm install && nvm use'
    exit 1
fi

echo '[1/3] Build the Qt bridge'
"$qt/bin/qt-cmake" -S native-plugin -B native-plugin/build-ios -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$(command -v ninja)" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_BUILD_TYPE=Release
cmake --build native-plugin/build-ios
libs=native-plugin/src/ios/libs
mkdir -p "$libs"
cp native-plugin/build-ios/libSqlitePoc.a "$libs/"
cp "$qt/lib/QtSql.framework/QtSql" "$libs/libQtSql.a"
cp "$qt/lib/QtCore.framework/QtCore" "$libs/libQtCore.a"
cp "$qt/lib/libQt6BundledPcre2.a" "$libs/libQtPcre2.a"
cp "$qt/plugins/sqldrivers/libqsqlite.a" "$libs/libQSQLite.a"

echo '[2/3] Prepare Cordova'
npm ci
cordova="$PWD/node_modules/.bin/cordova"
# This PoC regenerates the Xcode project on every build. Remove iOS before
# refreshing the plugin so Cordova never runs its pod-removal code for iOS.
rm -rf platforms/ios
rm -f plugins/ios.json
if "$cordova" plugin list | grep -q '^cordova-plugin-sqlite-poc '; then
    "$cordova" plugin remove cordova-plugin-sqlite-poc --nosave
fi
"$cordova" plugin add ./native-plugin --nosave
"$cordova" platform add ios --nosave

echo '[3/3] Build the iOS simulator app'
"$cordova" build ios --emulator -- --buildFlag=ARCHS=arm64
echo 'App: platforms/ios/build/Debug-iphonesimulator/SqliteMobilePoc.app'
