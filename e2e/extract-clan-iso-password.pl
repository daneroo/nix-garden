#!/usr/bin/env perl

# Formatted with: perltidy -b extract-clan-iso-password.pl

# invoke in a loop, to test
# for i in {1..10}; do echo -e "\n=== iteration $i ==="; ./extract-clan-iso-password.pl; qm reset 997; sleep 40; done

use strict;
use warnings;
use Socket;
use Time::HiRes qw(time sleep);
use IO::Select;
use IPC::Open2;

# Enable autoflush for immediate output
$| = 1;

# Configuration
my $VMID         = 997;
my $DEBUG_OUTPUT = 0;     # set to 1 to enable debug output
my $JSONLike_Regexp =
  qr/^\s*\{.*\}\s*$/;     # validate QMP output as valid JSON-like format
my $DUMP     = "/tmp/vm${VMID}.mem";
my $MAX_WAIT = 60;
my $SOCK     = "/var/run/qemu-server/${VMID}.qmp";
my @spinner  = ( '-', '\\', '|', '/' );              # shared progress spinner

# NOTE: Non-idiomatic style - calling functions before defining them (top-down readability)
# This works because we use parentheses which tell Perl these are function calls

main();

sub main {
    validate_configuration();
    execute_qmp_commands();
    wait_for_dump_completion();
    extract_passwords();
    cleanup();
}

sub validate_configuration {
    print "## Arguments validation:\n\n";
    print "- VMID: $VMID\n";
    print "- DUMP: $DUMP\n";
    print "- MAX_WAIT: $MAX_WAIT\n\n";
}

sub execute_qmp_commands {

    # 1. QMP capabilities + dump-guest-memory
    my $dump_escaped = $DUMP;
    $dump_escaped =~ s/\//\\\//g;

    # Use bidirectional communication with socat to capture responses
    my ( $socat_in, $socat_out );
    my $pid = open2( $socat_out, $socat_in, "socat - UNIX-CONNECT:$SOCK" )
      or die "socat: $!";

    # Read initial QMP greeting
    my $greeting = <$socat_out>;
    print "DEBUG: QMP greeting: $greeting" if $DEBUG_OUTPUT;

    print $socat_in '{"execute":"qmp_capabilities"}' . "\n";
    my $caps_response = <$socat_out>;
    print "DEBUG: Capabilities response: $caps_response" if $DEBUG_OUTPUT;
    if ( $caps_response && $caps_response =~ /$JSONLike_Regexp/ ) {
        print "✓ - qmp_capabilities (valid json)\n";
    }
    else {
        print "✗ - qmp_capabilities - invalid json response\n";
    }

    sleep(1);    # avoid handshake race

    print $socat_in
      '{"execute":"dump-guest-memory","arguments":{"protocol":"file:'
      . $dump_escaped
      . '","paging":false,"detach":false}}' . "\n";
    my $dump_response = <$socat_out>;
    print "DEBUG: Dump response: $dump_response" if $DEBUG_OUTPUT;
    if ( $dump_response && $dump_response =~ /$JSONLike_Regexp/ ) {
        print "✓ - dump-guest-memory (valid json)\n";
    }
    else {
        print "✗ - dump-guest-memory - invalid json response\n";
    }

    close($socat_in);
    close($socat_out);
    waitpid( $pid, 0 );
}

sub wait_for_dump_completion {

    # 2. Wait for dump completion
    my $prev = 0;
    for my $i ( 0 .. $MAX_WAIT * 2 ) {    # 0.5-s steps
        my $size      = -s $DUMP || 0;
        my $spin_char = $spinner[ $i % 4 ];
        printf "\r%s - waiting for dump %d bytes", $spin_char, $size;

        if ( $size != 0 && $size == $prev ) {
            printf "\r✓ - dump complete %d bytes\n", $size;
            last;
        }
        $prev = $size;
        sleep(0.5);
    }

    # Debug: check if dump file was created
    system("ls -l $DUMP 2>/dev/null || echo 'DEBUG: dump file not yet created'")
      if $DEBUG_OUTPUT;
}

sub extract_passwords {

    print "- extract password\n";

    # 3.1 PCRE method (full file load)
    my $start   = time();
    my $pw_pcre = "";
    print "  \\ - scanning memory dump (PCRE)";
    if ( open( my $fh, '<:raw', $DUMP ) ) {
        local $/;
        my $content = <$fh>;
        if ( $content =~ /"pass"\s*:\s*"([a-z]+-[a-z]+-[a-z]+)"/s ) {
            $pw_pcre = $1;
        }
        close($fh);
    }
    my $end = time();
    printf "\r  ✓ - root password: %s (PCRE %.3f s)\n", $pw_pcre, $end - $start;

    # 3.2 Perl stream method (with progress)
    $start = time();
    my $pw_perl = "";
    if ( open( my $fh, '<:raw', $DUMP ) ) {
        local $/ = \32_000_000;    # 32 MB blocks
        my $chunk_count = 0;
        while ( my $chunk = <$fh> ) {
            my $spin_char = $spinner[ $chunk_count % 4 ];
            printf "\r  %s - scanning chunk %d (Perl)", $spin_char,
              $chunk_count + 1;
            $chunk_count++;
            if ( $chunk =~ /"pass"\s*:\s*"([a-z]+-[a-z]+-[a-z]+)"/s ) {
                $pw_perl = $1;
                last;
            }
        }
        close($fh);
    }
    $end = time();
    printf "\r  ✓ - root password: %s (Perl %.3f s)\n", $pw_perl, $end - $start;
}

sub cleanup {

    # Cleanup
    unlink($DUMP);
}
