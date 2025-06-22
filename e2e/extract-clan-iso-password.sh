#!/bin/bash

# invoke in a loop, to test
# for i in {1..10}; do echo -e "\n=== iteration $i ==="; ./extract-clan-iso-password.sh; qm reset 997; sleep 40; done

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

# NOTE: Both QMP commands must be sent through same connection for session continuity
{
  echo '{"execute":"qmp_capabilities"}'
  sleep 1  # avoid handshake race
  echo '{"execute":"dump-guest-memory",'\
'"arguments":{"protocol":"file:'${DUMP//\//\\/}'",'\
'"paging":false,"detach":false}}'
} | socat - UNIX-CONNECT:"$SOCK" >/dev/null

echo "✓ - qmp_capabilities"
echo "✓ - dump-guest-memory"

echo -n "# 2  waiting for dump "
prev=0
for ((i=0; i<MAX_WAIT*2; i++)); do          # 0.5-s steps → MAX_WAIT seconds
  size=$(stat -c%s "$DUMP" 2>/dev/null || echo 0)
  printf "\r# 2  waiting for dump %s bytes" "$size"
  if [ "$size" -ne 0 ] && [ "$size" -eq "$prev" ]; then
    printf "\r✓ - dump complete %s bytes\n" "$size"
    break
  fi
  prev=$size
  sleep 0.5
done

echo "# 3  extract password"

# 3.1  strings scan (≈ 40 s) - REFERENCE ONLY
# start=$(date +%s%3N)
# pw_strings=$(strings -n 3 "$DUMP" |
#              grep -Eo '"pass"[[:space:]]*:[[:space:]]*"[a-z]+-[a-z]+-[a-z]+"' |
#              head -n1 | cut -d'"' -f4)
# end=$(date +%s%3N)
# printf "✓ - root password: %s (strings %.3f s)\n" "$pw_strings" "$(bc <<< "scale=3; ($end-$start)/1000")"

# 3.2  PCRE grep (≈ 6 s)
start=$(date +%s%3N)
pw_pcre=$(grep -aPzo -m1 '"pass"\s*:\s*"\K[a-z]+-[a-z]+-[a-z]+' "$DUMP" | tr -d '\0')
end=$(date +%s%3N)
printf "✓ - root password: %s (PCRE %.3f s)\n" "$pw_pcre" "$(bc <<< "scale=3; ($end-$start)/1000")"

# 3.3  Perl stream (≈ 0.4 s)
start=$(date +%s%3N)
pw_perl=$(perl - <<'PERL' "$DUMP"
use strict;
local $/ = \32_000_000;          # 32 MB blocks
while (<>) {
    if (/"pass"\s*:\s*"([a-z]+-[a-z]+-[a-z]+)"/s) { print "$1\n"; last }
}
PERL
)
end=$(date +%s%3N)
printf "✓ - root password: %s (chunked %.3f s)\n" "$pw_perl" "$(bc <<< "scale=3; ($end-$start)/1000")"

rm -f "$DUMP"
