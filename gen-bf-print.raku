#!/usr/bin/env raku

# This program reads STDIN and generates to STDOUT a brainfuck code,
# which will print the given input.
# The output code is designed to operate in two adjucent cells.
# Extra debug info goes to STDERR, so feel free to `2> /dev/null`.

use v6.d;

# given non-negative $n returns ($a, $b, $m), so $n == $a * $b + $m;
# $a and $b are at least 1.
# $m is at least 0.
sub consist(Int:D $n) {
    my $a = ($n ** 0.5).floor;
    my $b = ($n / $a).floor;
    my $m = $n - $a * $b;
    return ($a, $b, $m);
}

# returns code to change cur cell by the given delta
#
# BF memory both before and after:
#   ... 0 n ...
#         ^
sub adder(Int:D $delta) {
    return "" unless $delta;
    my ($c, $C) = $delta > 0 ?? <+ -> !! <- +>;
    my $n = $delta.abs;
    my ($a, $b, $m) = consist($n);
    $*ERR.print: "= $a * $b + $m";
    return $c x $n if $a + $b + $m + 6 >= $n;
    return "<{$c x $a}[>{$c x $b}<$C]>{$c x $m}";
}

# gather all fragments first, so all debug will gone
# print the final result in the end, so it's fine in TTY
# even without silenced STDERR
gather {
    take '>';
    my Int:D $prev = 0;
    for $*IN.slurp.split("", :skip-empty)>>.ord {
        my $delta = .self - $prev;
        $*ERR.print: "{.fmt('%3d')} => {$delta.fmt('%+d')} ";
        my $code = adder($delta);

        $prev = .self;
        take "{$code}.";
        $*ERR.say: " | $code";
    }
}.join("\n").subst(/^ '>' \s* '<'/).say;
