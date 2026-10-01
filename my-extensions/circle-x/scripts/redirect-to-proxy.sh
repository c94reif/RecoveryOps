#!/usr/bin/env bash


PORT="${1:-8080}"

DEVICES=$(adb devices | grep 'device$' | awk '{print $1}')

if [ -z "$DEVICES" ]; then
  echo "No devices connected."
  exit 1
fi

for DEVICE in $DEVICES; do
  echo "Setting up adb reverse tcp:$PORT on $DEVICE..."
  adb -s "$DEVICE" reverse tcp:"$PORT" tcp:"$PORT"
  echo "  Done."
done

echo ""
echo "All devices can now reach 127.0.0.1:$PORT -> host:$PORT"
