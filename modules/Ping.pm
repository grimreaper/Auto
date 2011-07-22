# Module: Ping. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Ping;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del hook_add hook_del rchook_add rchook_del has_priv match_user);
use API::IRC qw(privmsg notice who);
my (@PING, $STATE, %AWAY);
my $LAST = 0;

# Initialization subroutine.
sub _init {
    # Create the PING command.
    cmd_add('PING', 0, 'cmd.ping', \%M::Ping::HELP_PING, \&M::Ping::cmd_ping) or return;
    # Create the AWAY command.
    cmd_add('AWAY', 1, 0, \%M::Ping::HELP_AWAY, \&M::Ping::cmd_away) or return;
    # Create the on_whoreply hook.
    hook_add('on_whoreply', 'ping.who', \&M::Ping::on_whoreply) or return;

    # Hook onto numeric 315.
    rchook_add('315', 'ping.eow', \&M::Ping::ping) or return;

    # We don't support PostgreSQL (Not exactly sure why, though)
    if ($Auto::ENFEAT =~ /pgsql/) { err(2, 'Unable to load Ping: PostgreSQL is not supported.', 0); return }

    # Create table if it doesn't already exist
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS away (nick TEXT)') or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the PING command.
    cmd_del('PING') or return;
    # Delete the AWAY command.
    cmd_del('AWAY') or return;
    # Delete the on_whoreply hook.
    hook_del('on_whoreply', 'ping.who') or return;
    # Delete 315 hook.
    rchook_del('315', 'ping.eow') or return;

    # Success.
    return 1;
}

# Help for PING.
our %HELP_PING = (
    en => "This command will ping all non-/away users in the channel. \2Syntax:\2 PING",
);

# Help for AWAY.
our %HELP_AWAY = (
    en => "This command will toggle your away status for the PING command. \2Syntax:\2 AWAY",
);

# Callback for PING command.
sub cmd_ping {
    my ($src, @argv) = @_;

    # Check ratelimit (once every five minutes).
    if ((time - $LAST) < 300 and !has_priv(match_user(%{$src}), 'cmd.ping.admin')) {
        notice($src->{svr}, $src->{nick}, 'This command is ratelimited. Please wait a while before using it again.');
        return;
    }

    # Set last used time to current time.
    $LAST = time;
    # Set state.
    $STATE = $src->{svr}.'::'.$src->{chan};

    # Ship off a WHO.
    who($src->{svr}, $src->{chan});

    return 1;
}

# Callback for AWAY command.
sub cmd_away {
    my ($src, @argv) = @_;

    # Toggle their away status.
    my $cdbq = $Auto::DB->prepare('SELECT * FROM away WHERE nick = ?');
    $cdbq->execute(lc $src->{nick});
    if ($cdbq->fetchrow_array) {
        my $dbq = $Auto::DB->prepare('DELETE FROM away WHERE nick = ?');
	$dbq->execute(lc $src->{nick}) or notice($src->{svr}, $src->{nick}, 'An error occurred.  You are still away.') and return;
	privmsg($src->{svr}, $src->{nick}, 'You are now back.');
    }
    else {
        my $dbq = $Auto::DB->prepare('INSERT INTO away (nick) VALUES (?)');
	$dbq->execute(lc $src->{nick}) or notice($src->{svr}, $src->{nick}, 'An error occurred.  You are still back.') and return;
	privmsg($src->{svr}, $src->{nick}, 'You are now away.');
    }

    return 1;
}

# Callback for WHO reply.
sub on_whoreply {
    my ($svr, $nick, $target, undef, undef, undef, $status, undef, undef) = @_;
    
    # If it's us, just return.
    if ($nick eq $State::IRC::botinfo{$svr}{nick}) { return 1 }

    # Check if we're doing a ping right now.
    if ($STATE) {
        # Check if this is the target channel.
        if ($STATE eq $svr.'::'.$target) {
            my $cdbq = $Auto::DB->prepare('SELECT * FROM away WHERE nick = ?');
	    $cdbq->execute(lc $nick);
            # If their status is not away, push to ping array.
            if ($status !~ m/(G|\+)/xsm and !$cdbq->fetchrow_array) {
                push @PING, $nick;
            }
        }
    }

    return 1;
}

# Ping!
sub ping {
    if ($STATE) {
        my ($svr, $chan) = split '::', $STATE, 2;
        privmsg($svr, $chan, 'PING! '.join(' ', @PING));
        @PING = ();
        $STATE = 0;
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('Ping', 'Xelhua', '1.03', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

 Ping - A module for pinging a channel.

=head1 VERSION

 1.03

=head1 SYNOPSIS

 <Hermione> .ping   
 <howlbot> PING! `A` tdubellz Hermione Oakfeather LightToagac shadowm_goat kitten starcoder2 Suiseiseki metabill theknife Trashlord Cam HardDisk_WP nerdshark2 MJ94 JonathanD Julius2 CensoredBiscuit LordVoldemort e36freak alyx mth starcoder

=head1 DESCRIPTION

This creates the PING command, which will highlight everyone in the channel,
excluding the bot itself and those who are /away.

This also creates the AWAY command, which will make the bot see people who
use it as /away, regardless of their actual status. When used again, they
reappear.

It requires the cmd.ping privilege, also cmd.ping.admin overrides the
ratelimit.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module was patched by Douglas Freed <dwfreed@mtu.edu>.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:
