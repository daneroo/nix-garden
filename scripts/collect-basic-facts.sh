#!/usr/bin/env bash
set -euo pipefail

echo "== hostnamectl =="
hostnamectl || true

echo
echo "== lscpu =="
lscpu || true

echo
echo "== memory =="
free -h || true

echo
echo "== block devices =="
lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS,ROTA,TRAN || true

echo
echo "== CPU performance controls =="
for directory in /sys/devices/system/cpu/intel_pstate /sys/devices/system/cpu/amd_pstate; do
  [ -d "$directory" ] || continue
  for file in "$directory"/*; do
    [ -e "$file" ] || continue
    printf '%s/%s=' "${directory##*/}" "${file##*/}"
    cat "$file" || true
  done
done

echo
echo "== thermal cooling devices =="
for device in /sys/class/thermal/cooling_device*; do
  [ -e "$device/type" ] || continue
  type=$(cat "$device/type" 2>/dev/null || true)
  case "$type" in
    *powerclamp*|Processor|TFN1|TCC*|TCHG)
      printf '%s %s cur=' "$device" "$type"
      cat "$device/cur_state" 2>/dev/null || true
      printf 'max='
      cat "$device/max_state" 2>/dev/null || true
      ;;
  esac
done
