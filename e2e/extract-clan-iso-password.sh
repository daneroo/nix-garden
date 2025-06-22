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

echo "# 3  extract password - 3 methods - 1 skipped"

# Skipping this reference method, as it's too slow
# 3.0  strings scan (≈ 40 s)
# start=$(date +%s%3N)
# pw_strings=$(strings -n 3 "$DUMP" |
#              grep -Eo '"pass"[[:space:]]*:[[:space:]]*"[a-z]+-[a-z]+-[a-z]+"' |
#              head -n1 | cut -d'"' -f4)
# end=$(date +%s%3N)
# printf "# 3.0  done in %.3f s (strings scan)\n" "$(bc <<< "scale=3; ($end-$start)/1000")"
# echo "root password (strings): $pw_strings"

# 3.1  PCRE grep (≈ 6 s)
start=$(date +%s%3N)
pw_pcre=$(grep -aPzo -m1 '"pass"\s*:\s*"\K[a-z]+-[a-z]+-[a-z]+' "$DUMP" | tr -d '\0')
end=$(date +%s%3N)
printf "# 3.1  done in %.3f s (PCRE)\n" "$(bc <<< "scale=3; ($end-$start)/1000")"
echo "root password (PCRE):   $pw_pcre"

# 3.2  Perl stream (≈ 0.4 s)
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
printf "# 3.2  done in %.3f s (Perl stream)\n" "$(bc <<< "scale=3; ($end-$start)/1000")"
echo "root password (Perl):   $pw_perl"

rm -f "$DUMP"
