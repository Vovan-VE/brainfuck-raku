#!/usr/bin/env raku

# Brainfuck interpretter made just for fun as an excersize for Raku.
#
# bf [options]
#
#     Reads the source code from STDIN and executes it.
#
# Options
#
#     -e STRING
#         Execute the given code instead of STDIN.
#
#     -l LENGTH
#         Set memory size to the given length. Default is 1 MiB.
#
#     -D
#         Enable dump mode. Memory state is printed to STDERR after
#         every operation executed.
#
#     -C SIZE
#         In dump mode `-D` changes the memory context size.
#         Default is 20 byte.

use v6.d;

my Int:D $len = 1 +< 20;
my Int:D $dump-ctx = 20;
my Str $code;
my Bool:D $dump = False;
# Getopt::Std? Nah! It's excersize.
while @*ARGS.elems {
    my Str:D $arg = @*ARGS[0];
    given $arg {
        when "-l" {
            @*ARGS.shift;
            @*ARGS.elems or die "option $arg requires value\n";
            $len = +@*ARGS[0];
            $len > 0 or die "option $arg must be positive\n";
        }
        when "-C" {
            @*ARGS.shift;
            @*ARGS.elems or die "option $arg requires value\n";
            $dump-ctx = +@*ARGS[0];
            $dump-ctx > 0 or die "option $arg must be positive\n";
        }
        when "-e" {
            @*ARGS.shift;
            @*ARGS.elems or die "option $arg requires value\n";
            $code = @*ARGS[0];
        }
        when "-D" {
            $dump = True;
        }
        when "--" {
            @*ARGS.shift;
            last;
        }
        when / ^ '-' / { die "unrecognized option $arg\n"; }
        default {
            last;
        }
    }
    @*ARGS.shift;
}

$code = $*IN.slurp without $code;

$code ~~ / <-[ -+<>,. \[ \] \s ]> / and die "invalid char found in BF code: {$/.Str.raku} at offset {$/.from}\n";

grammar BF {
    token TOP      { <fragments>           }
    rule fragments { [ <flow> || <loop> ]* }
    rule flow      { <[ -+<>,. ]>+         }
    rule loop      { '[' <fragments> ']'   }
}
#class BF {
#    method TOP ($/)       {  }
#    method fragments ($/) {  }
#    #method flow ($/)      {  }
#    method loop ($/)      { make $<fragments>.made }
#}
my $bf = BF.subparse($code) or die "parse failure\n";
$bf.to == $code.chars or die "invalid [ ] nesting at offset {$bf.to}\n";

my uint8 @data[$len] = 0 xx $len;
my Int:D $p = 0;

sub hex2(Int:D $i --> Str:D) { $i.fmt("%02X") }

sub dump-char(Int:D $i --> Str:D) {
    with $i {
        return .chr when 0x20 .. 0x7E;
        return ' ';
    }
}

sub dump(Str $caused = Str) {
    return unless $dump;

    my $from = $p - $dump-ctx max 0;
    my $to   = $p + $dump-ctx min $len - 1;
    my $s = '{';
    $s ~= "...[$from]" if $from;
    for $from .. $to -> $i {
        $s ~= " ";
        $s ~= do given hex2(@data[$i]) {
            when $i == $p { "<{.self}>" }
            default       { .self }
        };
    }
    $s ~= "..." if $to < $len - 1;
    $s ~= ' }';
    my $c = @data[$p];
    $*ERR.say: "{$caused // ' '} [$p] {$c.fmt("%3d")} | {hex2($c)} | {dump-char($c)} | $s";
}

sub read-char( --> uint8) {
    return 0 if $*IN.eof;
    given $*IN.getc {
        when Nil { 0 }
        default { .ord }
    }
}

sub run-flow(Match $flow) {
    for $flow.Str.split("", :skip-empty) {
        {
            when "+" { @data[$p]++; }
            when "-" { @data[$p]--; }
            when "<" { $p--; $p >= 0   or $p = $len - 1; }
            when ">" { $p++; $p < $len or $p = 0; }
            when "." { @data[$p].chr.print; }
            when "," { @data[$p] = read-char(); }
            default  { next }
        }
        dump(.self);
    }
}

sub run-loop(Match $loop) {
    while @data[$p] {
        run-fragments($loop<fragments>);
    }
}

sub run-fragments(Match $fragments) {
    for $fragments.caps {
        when defined .<flow> { run-flow(.<flow>) }
        when defined .<loop> { run-loop(.<loop>) }
        default { warn .self; die "unexpected match" }
    }
}

dump();
run-fragments($bf<fragments>);
