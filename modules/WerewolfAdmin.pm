# Module: WerewolfAdmin. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::WerewolfAdmin;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(cmd_add cmd_del timer_add timer_del trans conf_get);
use API::IRC qw(privmsg notice cmode ison);

# Initialization subroutine.
sub _init {
    # Create the WOLFA command.
    cmd_add('WOLFA', 0, 'werewolf.admin', \%M::WerewolfAdmin::HELP_WOLFA, \&M::WerewolfAdmin::cmd_wolfa) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the WOLFA command.
    cmd_del('WOLFA') or return;

    # Success.
    return 1;
}

# Help hash for the WOLFA command.
our %HELP_WOLFA = (
    en => "This command allows you to perform various administrative actions in a game of Werewolf (A.K.A. Mafia). \2Syntax:\2 WOLFA (JOIN|WAIT|START|KICK|STOP) [parameters]",
);

# Callback for the WOLFA command.
sub cmd_wolfa {
    my ($src, @argv) = @_;

    # We require at least one parameter.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # For garbage data.
    if ($src->{chan}) { $src->{chan} = lc $src->{chan} }

    # Iterate the parameter.
    given (uc $argv[0]) {
        when (/^(JOIN|J)$/) {
            # WOLFA JOIN

            # Requires an extra parameter.
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }

            # Check if a game is running.
            if (!$M::Werewolf::PGAME and !$M::Werewolf::GAME) {
                notice($src->{svr}, $src->{nick}, 'No game is currently running.');
            }
            elsif ($M::Werewolf::GAME) {
                notice($src->{svr}, $src->{nick}, 'Sorry, but the game is already running. Try again next time.');
            }
            else {
                # Check if this is the game channel.
                if ($src->{svr}.'/'.$src->{chan} ne $M::Werewolf::GAMECHAN) {
                    notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$M::Werewolf::GAMECHAN\2.");
                    return;
                }

                # Check if this user exists in channel.
                if (!ison($src->{svr}, $src->{chan}, lc $argv[1])) {
                    notice($src->{svr}, $src->{nick}, "No such user \2$argv[1]\2 is on the channel.");
                    return;
                }

                # Make sure they're not already playing.
                if (exists $M::Werewolf::PLAYERS{lc $argv[1]}) {
                    notice($src->{svr}, $src->{nick}, 'They\'re already playing!');
                    return;
                }

                # Set variables.
                $M::Werewolf::PLAYERS{lc $argv[1]} = 0;
                my $nick = $M::Werewolf::NICKS{lc $argv[1]} = $Core::IRC::Users::users{$src->{svr}}{lc $argv[1]};

                # Send message.
                my ($gsvr, $gchan) = split '/', $M::Werewolf::GAMECHAN, 2;
                cmode($gsvr, $gchan, "+v $nick");
                privmsg($gsvr, $gchan, "\2$nick\2 was forced to join the game by \2$src->{nick}\2.");
            }
        }
        when (/^(WAIT|W)$/) {
            # WOLFA WAIT

            # Check if a game is running.
            if (!$M::Werewolf::PGAME) {
                if (!$M::Werewolf::GAME) {
                    notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                    return;
                }
                else {
                    notice($src->{svr}, $src->{nick}, 'Werewolf is already in play.');
                    return;
                }
            }

            # Check if this is the game channel.
            if ($src->{svr}.'/'.$src->{chan} ne $M::Werewolf::GAMECHAN) {
                notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$M::Werewolf::GAMECHAN\2.");
                return;
            }

            # Increase WAIT.
            $M::Werewolf::WAIT += 20;
            # And WAITED.
            $M::Werewolf::WAITED++;
            privmsg($src->{svr}, $src->{chan}, "\2$src->{nick}\2 forcibly increased join wait time by 20 seconds.");
        }
        when ('START') {
            # WOLFA START
            M::Werewolf::cmd_wolf($src, @argv);
        }
        when (/^(KICK|K)$/) {
            # WOLFA KICK

            # Check if a game is running.
            if (!$M::Werewolf::GAME and !$M::Werewolf::PGAME) {
                notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                return;
            }

            # Check if this is the game channel.
            if ($src->{svr}.'/'.$src->{chan} ne $M::Werewolf::GAMECHAN) {
                notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$M::Werewolf::GAMECHAN\2.");
                return;
            }

            # Requires an extra parameter.
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }

            # Check if the target is playing.
            if (!exists $M::Werewolf::PLAYERS{lc $argv[1]}) {
                notice($src->{svr}, $src->{nick}, "\2$argv[1]\2 is not currently playing.");
                return;
            }

            # Kill the target.
            privmsg($src->{svr}, $src->{chan}, "\2$argv[1]\2 died of an unknown disease. He/She was a \2".M::Werewolf::_getrole(lc $argv[1], 2)."\2.");
            M::Werewolf::_player_del(lc $argv[1]);
        }
        when ('STOP') {
            # WOLFA STOP

            # Check if a game is running.
            if (!$M::Werewolf::GAME and !$M::Werewolf::PGAME) {
                notice($src->{svr}, $src->{nick}, 'No game is currently running.');
                return;
            }

            # Check if this is the game channel.
            if ($src->{svr}.'/'.$src->{chan} ne $M::Werewolf::GAMECHAN) {
                notice($src->{svr}, $src->{nick}, "Werewolf is currently running in \2$M::Werewolf::GAMECHAN\2.");
                return;
            }

            # End the game.
            my ($gsvr, $gchan) = split '/', $M::Werewolf::GAMECHAN, 2;
            privmsg($gsvr, $gchan, "\2$src->{nick}\2 is forcing the game to end...");
            M::Werewolf::_gameover('n');
        }
        default { notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.}) }
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('WerewolfAdmin', 'Xelhua', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

WerewolfAdmin - Administrative functions for Werewolf

=head1 VERSION

 1.00

=head1 SYNOPSIS

None

=head1 DESCRIPTION

This module allows one to administer the Werewolf IRC game, provided by the
Werewolf module.

It provides the following commands:

 WOLFA JOIN|J - Force join.
 WOLFA WAIT - Force wait.
 WOLFA START - Force start.
 WOLFA KICK|K - Kick a player.
 WOLFA STOP - Stop a game forcibly.

And requires the werewolf.admin privilege.

=head1 DEPENDENCIES

This module depends on the following Auto module(s):

=over

=item Werewolf

The Werewolf module provides the game that this module provides administrative
commands for. Using this module without Werewolf will likely cause a fatal
error.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright (C) 2010-2011, Xelhua Development Group.

This module is released under the same terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:
