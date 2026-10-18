#!/usr/bin/env bash
# Open Leca on a phone window on this Mac, then leave `flutter run` attached.
#
#   ./scripts/run-device.sh                 # names, and what is already booted
#   ./scripts/run-device.sh duo             # iPhone Duo
#   ./scripts/run-device.sh 18-pro-max      # iPhone 18 Pro Max
#   ./scripts/run-device.sh 18-pro
#   ./scripts/run-device.sh 17-pro-max
#   ./scripts/run-device.sh android         # Android 15 Pixel, Google account skipped
#   ./scripts/run-device.sh android-17      # Android 17 Pixel (does not finish booting here)
#
# iOS. Xcode 27 draws the phone in DeviceHub
# (Xcode.app/Contents/Applications/DeviceHub.app). This Xcode has no
# Simulator.app, so `open -a Simulator` does nothing.
#
# The installed runtime is iOS 27.1. That runtime boots iPhone Duo. The other
# names above are real device types, and simctl answers "Incompatible device"
# for them against this runtime. The command still tries, and prints that
# answer, so a newer runtime can be dropped in without changing the names.
#
# Android. `android` is the AVD chow: a Pixel on Android 15 that does boot
# on this Mac. Its first screen is a Google account prompt. This script marks
# setup finished and presses Home so that screen does not stay in front of Leca.
# `android-17` is leca_android_17, Android 17 (API 37.2, 16 KB pages). This
# Mac's emulator opens that window and then does not finish booting the guest.
# The window, when the guest runs, is the Android Emulator, not DeviceHub.
#
# Override the API with LECA_AUTH_API. The default matches ./build.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTH_API="${LECA_AUTH_API:-https://gno.money}"
DEVICEHUB="/Applications/Xcode.app/Contents/Applications/DeviceHub.app"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"

export PATH="${SDK_ROOT}/emulator:${SDK_ROOT}/platform-tools:/opt/homebrew/bin:${HOME}/flutter/flutter/bin:${PATH}"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export ANDROID_HOME="$SDK_ROOT"

die() {
  echo "run-device: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ./scripts/run-device.sh [name]

  duo            iPhone Duo, the phone iOS 27.1 boots on this Mac
  18-pro         iPhone 18 Pro
  18-pro-max     iPhone 18 Pro Max
  17-pro         iPhone 17 Pro
  17-pro-max     iPhone 17 Pro Max
  17             iPhone 17
  air            iPhone Air
  android        Android 15 Pixel (AVD chow). Skips the Google account screen.
  android-17     Android 17 Pixel (AVD leca_android_17). The guest does not finish booting on this Mac.

No name lists those names and the simulators that are already booted.
The iOS window is DeviceHub. The Android window is the Android Emulator.
EOF
}

# $1 alias -> device type display name, or "android"
resolve() {
  case "$1" in
    duo | iphone-duo) echo "iPhone Duo" ;;
    18-pro | 18pro) echo "iPhone 18 Pro" ;;
    18-pro-max | 18promax | "18 pro max") echo "iPhone 18 Pro Max" ;;
    17-pro | 17pro) echo "iPhone 17 Pro" ;;
    17-pro-max | 17promax | "17 pro max") echo "iPhone 17 Pro Max" ;;
    17) echo "iPhone 17" ;;
    air | iphone-air) echo "iPhone Air" ;;
    android | pixel | chow) echo "android" ;;
    android-17 | 17) echo "android-17" ;;
    -h | help) echo "help" ;;
    *) die "unknown device '$1' (try: duo, 18-pro-max, android)" ;;
  esac
}

ios_runtime() {
  local line
  line="$(xcrun simctl list runtimes 2>/dev/null | awk '/iOS / { print; exit }')"
  [[ -n $line ]] || die "no iOS simulator runtime is installed"
  # "iOS 27.1 (24A94425) - <uuid> (Ready)" -> "iOS 27.1"
  echo "$line" | awk '{ print $1, $2 }'
}

# Print the UDID of a simulator whose name is exactly $1, if one exists.
find_udid() {
  local name=$1
  xcrun simctl list devices available | awk -v name="$name" '
    index($0, name " (") && match($0, /\([0-9A-F-]{36}\)/) {
      print substr($0, RSTART + 1, RLENGTH - 2)
      exit
    }
  '
}

open_ios_window() {
  local udid=$1
  if [[ -d $DEVICEHUB ]]; then
    open "$DEVICEHUB"
    open "devices://${udid}" || true
  fi
}

boot_ios() {
  local pretty=$1 udid runtime
  command -v xcrun >/dev/null || die "xcrun is missing; this command runs on the Mac"
  runtime="$(ios_runtime)"
  udid="$(find_udid "$pretty")"
  if [[ -z $udid ]]; then
    echo "run-device: creating ${pretty} on ${runtime}"
    if ! udid="$(xcrun simctl create "Leca ${pretty}" "$pretty" "$runtime")"; then
      die "${pretty} was not created. iOS 27.1 on this Mac boots iPhone Duo; other models need a runtime that includes them."
    fi
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  open_ios_window "$udid"
  echo "run-device: ${pretty} ${udid}"
  echo "$udid"
}

# The Google APIs image opens an account screen before the launcher.
# Marking setup complete and pressing Home leaves Leca in front.
skip_google_setup() {
  local serial=$1
  adb -s "$serial" shell settings put global device_provisioned 1 || true
  adb -s "$serial" shell settings put secure user_setup_complete 1 || true
  adb -s "$serial" shell am force-stop com.google.android.gms || true
  adb -s "$serial" shell input keyevent KEYCODE_HOME || true
}

boot_android() {
  local which=$1 serial avd want
  command -v emulator >/dev/null || die "emulator is missing (looked in ${SDK_ROOT}/emulator)"
  if [[ $which == android-17 ]]; then
    avd=leca_android_17
    want=17
  else
    avd=chow
    want=15
  fi
  emulator -list-avds | grep -qx "$avd" || die "AVD ${avd} is missing under ~/.android/avd."
  serial="$(adb devices | awk '/^emulator-/ { print $1 }' | while read -r s; do
    ver="$(adb -s "$s" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
    if [[ $ver == "$want"* ]]; then
      echo "$s"
      break
    fi
  done)"
  if [[ -z $serial ]]; then
    echo "run-device: starting ${avd}"
    # A logged-in Mac session shows the emulator window. nohup keeps it
    # after this script goes on to flutter run.
    nohup emulator -avd "$avd" -no-metrics -crash-report-mode never -netdelay none -netspeed full >/tmp/leca-android-emu.log 2>&1 &
    local i s ver
    for ((i = 0; i < 90; i++)); do
      serial=""
      while read -r s; do
        ver="$(adb -s "$s" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')"
        if [[ $ver == "$want"* && $(adb -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r') == 1 ]]; then
          serial=$s
          break
        fi
      done < <(adb devices | awk '/^emulator-/ { print $1 }')
      [[ -n $serial ]] && break
      sleep 2
    done
  fi
  [[ -n $serial ]] || die "${avd} did not finish booting"
  skip_google_setup "$serial"
  echo "run-device: ${which} ${serial}"
  echo "$serial"
}

run_flutter() {
  local id=$1
  cd "$ROOT"
  exec flutter run -d "$id" --dart-define="AUTH_API=${AUTH_API}"
}

main() {
  local arg=${1:-}
  if [[ -z $arg ]]; then
    usage
    echo
    if command -v xcrun >/dev/null; then
      echo "Booted simulators:"
      xcrun simctl list devices | awk '/Booted/' || true
    fi
    if command -v adb >/dev/null; then
      echo "Android:"
      adb devices | awk 'NR>1 && $2=="device"' || true
    fi
    exit 0
  fi
  local pretty id
  pretty="$(resolve "$arg")"
  if [[ $pretty == help ]]; then
    usage
    exit 0
  fi
  if [[ $pretty == android || $pretty == android-17 ]]; then
    id="$(boot_android "$pretty" | tail -1)"
  else
    id="$(boot_ios "$pretty" | tail -1)"
  fi
  run_flutter "$id"
}

main "$@"
