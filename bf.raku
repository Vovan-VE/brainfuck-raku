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
my Bool:D $debug = False;
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
            $debug = True;
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

sub hex2(Int:D $i --> Str:D) { $i.fmt("%02X") }

sub dump-char(Int:D $i --> Str:D) {
    with $i {
        return .chr when 0x20 .. 0x7E;
        return ' ';
    }
}

sub read-char( --> uint8) {
    return 0 if $*IN.eof;
    given $*IN.getc {
        when Nil { 0 }
        default { .ord }
    }
}

my class Memory {
    has Int:D  $.len is required;
    has Bool:D $.debug = False;
    has Int:D  $.dump-ctx is rw = 20;

    has uint8  @!data = 0 xx $!len;
    has Int:D  $!p = 0;

    method dump(Str $caused = Str) {
        return unless $!debug;

        my $from = $!p - $!dump-ctx max 0;
        my $to   = $!p + $!dump-ctx min $!len - 1;
        my $s = '{';
        $s ~= "...[$from]" if $from;
        for $from .. $to -> $i {
            $s ~= " ";
            $s ~= do given hex2(@!data[$i]) {
                when $i == $!p { "<{.self}>" }
                default        { .self }
            };
        }
        $s ~= "..." if $to < $!len - 1;
        $s ~= ' }';
        my $c = @!data[$!p];
        $*ERR.say: "{$caused // ' '} [$!p] {$c.fmt("%3d")} | {hex2($c)} | {dump-char($c)} | $s";
    }

    method inc()  { @!data[$!p]++; }
    method dec()  { @!data[$!p]--; }
    method next() { $!p++; $!p < $!len or $!p = 0; }
    method prev() { $!p--; $!p >= 0    or $!p = $!len - 1; }
    method out()  { @!data[$!p].chr.print; }
    method in()   { @!data[$!p] = read-char; }
    method current () { @!data[$!p]; }
}

my class Flow {
    has @.op;

    method run(Memory $memo) {
        for @!op {
            {
                when "+" { $memo.inc; }
                when "-" { $memo.dec; }
                when "<" { $memo.prev; }
                when ">" { $memo.next; }
                when "." { $memo.out; }
                when "," { $memo.in; }
            }
            $memo.dump(.self);
        }
    }
}
my class Loop {
    has $.f;

    method run(Memory $memo) {
        while $memo.current {
            $!f.run($memo);
        }
    }
}
my class Fragments {
    has @.fragments;

    method run(Memory $memo) {
        for @!fragments {
            .run($memo);
        }
    }
}

grammar G {
    token TOP      { <fragments>          }
    rule fragments { <fragment>*          }
    rule fragment  { <flow> || <loop>     }
    rule flow      { <[ -+<>,. ]>+        }
    rule loop      { '[' <fragments> ']'  }
}
class BF {
    method TOP ($/)       { make $<fragments>.made }
    method fragments ($/) { make Fragments.new(fragments => $<fragment>.list>>.made) }
    method fragment ($/)  { make ($<flow> // $<loop>).made }
    method flow ($/)      { make Flow.new(op => $/.Str.split('', :skip-empty)) }
    method loop ($/)      { make Loop.new(f => $<fragments>.made) }
}
my $bf = G.subparse($code, actions => BF.new) or die "parse failure\n";
$bf.to == $code.chars or die "invalid [ ] nesting at offset {$bf.to}\n";

my $memo = Memory.new(:$len, :$debug, :$dump-ctx);
$memo.dump;
$bf.made.run($memo);
