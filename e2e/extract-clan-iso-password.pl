#!/usr/bin/env perl
use strict;
use warnings;
use Socket;
use Time::HiRes qw(time sleep);
use IO::Select;

# Configuration
my $VMID = 997;
my $DUMP = "/tmp/vm${VMID}.mem";
my $MAX_WAIT = 60;
my $SOCK = "/var/run/qemu-server/${VMID}.qmp";

print "## Arguments validation:\n\n";
print "- VMID: $VMID\n";
print "- DUMP: $DUMP\n";
print "- MAX_WAIT: $MAX_WAIT\n\n";

# 1. QMP capabilities + dump-guest-memory
print "# 1  qmp_capabilities + dump-guest-memory\n";

my $dump_escaped = $DUMP;
$dump_escaped =~ s/\//\\\//g;

# Pipe directly to socat (like bash version)  
open(my $socat, '|-', "socat - UNIX-CONNECT:$SOCK >/dev/null") or die "socat: $!";
print $socat '{"execute":"qmp_capabilities"}' . "\n";
sleep(1);  # avoid handshake race
print $socat '{"execute":"dump-guest-memory","arguments":{"protocol":"file:' . $dump_escaped . '","paging":false,"detach":false}}' . "\n";
close($socat);

# 2. Wait for dump completion
print "# 2  waiting for dump ";
my $prev = 0;
for my $i (0 .. $MAX_WAIT * 2) {  # 0.5-s steps
    my $size = -s $DUMP || 0;
    printf "\r# 2  waiting for dump %d bytes", $size;
    
    if ($size != 0 && $size == $prev) {
        print "\n";
        last;
    }
    $prev = $size;
    sleep(0.5);
}

# Debug: check if dump file was created
system("ls -l $DUMP 2>/dev/null || echo 'DEBUG: dump file not yet created'");


print "# 3  extract password\n";

# 3.1 PCRE method
my $start = time();
my $pw_pcre = "";
if (open(my $fh, '<:raw', $DUMP)) {
    local $/;
    my $content = <$fh>;
    if ($content =~ /"pass"\s*:\s*"([a-z]+-[a-z]+-[a-z]+)"/s) {
        $pw_pcre = $1;
    }
    close($fh);
}
my $end = time();
printf "✓ - root password: %s (PCRE %.3f s)\n", $pw_pcre, $end - $start;

# 3.2 Perl stream method  
$start = time();
my $pw_perl = "";
if (open(my $fh, '<:raw', $DUMP)) {
    local $/ = \32_000_000;  # 32 MB blocks
    while (my $chunk = <$fh>) {
        if ($chunk =~ /"pass"\s*:\s*"([a-z]+-[a-z]+-[a-z]+)"/s) {
            $pw_perl = $1;
            last;
        }
    }
    close($fh);
}
$end = time();
printf "✓ - root password: %s (Perl %.3f s)\n", $pw_perl, $end - $start;

# Cleanup
unlink($DUMP); 