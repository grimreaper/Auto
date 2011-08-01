# Module: Rules. No documentation.
# Copyright (c) 2011 Elijah Perrault. All rights reserved.
# Released under the terms of the New BSD License.
package M::Rules;
use strict;
use warnings;
use API::Std qw/cmd_add cmd_del/;
use API::IRC qw/privmsg/;
my @rules = (
    '#wolfgame channel rules: 1) Be nice to others. 2) Do not share information after death. 3) No bots allowed. 4) Do not play with clones.',
    '5) Do not quit unless you need to leave. 6) No swearing and keep it family-friendly. 7) Do not paste PM\'s from the bot during the game. 8) Use common sense.',
);

sub _init {
    cmd_add('RULES', 2, 0, \%M::Rules::HELP_RULES, \&M::Rules::cmd_rules) or return;
    return 1;
}

sub _void {
    cmd_del('RULES') or return;
    return 1;
}

our %HELP_RULES = (
    en => "This command will PM you the #wolfgame channel rules. \2Syntax:\2 RULES",
);

sub cmd_rules {
    my ($src, undef) = @_;

    my $tg = $src->{nick};
    if ($src->{chan}) { $tg = $src->{chan} }

    for (@rules) { privmsg($src->{svr}, $tg, $_) }

    return 1;
}

API::Std::mod_init('Rules', 'starcoder', '1.00', '3.0.0a11');