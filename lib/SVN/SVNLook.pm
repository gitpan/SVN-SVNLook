package SVN::SVNLook;
use strict;
use warnings;

our $VERSION = 0.01;

=head1 NAME

SVN::SVNLook - Perl wrapper to the svnlook command.

=head1 SYNOPSIS

  use SVN::SVNLook;

  my $revision = 1;
  my $svnlook = SVN::SVNLook->new(repo => 'repo url',
                                   cmd => 'path to svn look');
  my ($author,$date,$logmessage) = $svnlook->info($revision);

  print "Author $author\n";
  print "Date $date\n";
  print "LogMessage $logmessage\n";

=head1 DESCRIPTION

SVN::SVNLook runs the command line client. This module was created to make adding
hooks script easier to manipulate

=cut

=head1 METHODs

=head2 info

  info ($revision);

Perform the info command, for a given revision.
The information returned is an array containing author,date,and log message

=head2 dirschanged

  dirschanged ($revision)

Performs the dirs-changed command, for a given revision.
This method returns a boolean and am array reference

=head2 fileschanged

  fileschanged ($revision)

Performs the changed command, for a given revision.
this method returns 3 aray references Added,deleted and modified

=head2 diff

  diff ($revision)

Performs the diff command, for a given revision.
this method returns a hash reference, with each file being the key and value being the diff info

=cut


sub new {
    my $class = shift;
    my $self = {};
    %$self = @_;
    return bless $self, $class unless $class eq __PACKAGE__;

    $self->{repospath} ||= $self->{target};
    die "no repository specified" unless $self->{repospath} || $self->{repos};
    die "no source specified" unless $self->{source} || $self->{get_source};
    return $self;
}

sub info
{
    my $self = shift;
    my $rev = shift;
    my @svnlooklines = _read_from_process($self->{svnlook}, 'info', $self->{repo}, '-r', $rev);
    my $author = shift @svnlooklines; # author of this change
    my $date = shift @svnlooklines; # date of change
    shift @svnlooklines; # log message size
    #pop(@svnlooklines);
    my @log = map { "$_\n" } @svnlooklines;
    my $logmessage = join('',@log);
    return ($author,$date,$logmessage);
}

sub dirschanged
{
    my $self = shift;
    my $rev = shift;
    # Figure out what directories have changed using svnlook.
    my @dirschanged = _read_from_process($self->{svnlook}, 'dirs-changed', $self->{repo},'-r', $rev);
    # Lose the trailing slash in the directory names if one exists, except
    # in the case of '/'.
    my $rootchanged = 0;
    for (my $i=0; $i<@dirschanged; ++$i)
    {
        if ($dirschanged[$i] eq '/')
        {
            $rootchanged = 1;
        }
        else
        {
            $dirschanged[$i] =~ s#^(.+)[/\\]$#$1#;
        }
    }
    return ($rootchanged,\@dirschanged);
}


sub fileschanged
{
    my $self = shift;
    my $rev = shift;

    # Figure out what files have changed using svnlook.
    my @svnlooklines = _read_from_process($self->{svnlook}, 'changed', $self->{repo}, '-r', $rev);
    # Parse the changed nodes.
    my @adds;
    my @dels;
    my @mods;
    foreach my $line (@svnlooklines)
    {
        my $path = '';
        my $code = '';

        # Split the line up into the modification code and path, ignoring
        # property modifications.
        if ($line =~ /^(.).  (.*)$/)
        {
            $code = $1;
            $path = $2;
        }
        if ($code eq 'A')
        {
            push(@adds, $path);
        }
        elsif ($code eq 'D')
        {
            push(@dels, $path);
        }
        else
        {
            push(@mods, $path);
        }
    }
    return (\@adds,\@dels,\@mods);
}

sub diff
{
    my $self = shift;
    my $rev = shift;
    my @difflines = _read_from_process($self->{svnlook}, 'diff', $self->{repo},'-r', $rev,
                                       ('--no-diff-deleted'));
    # Ok we need to split this out now , by file
    my @lin = split(/Modified: (.*)\n=*\n/,join("\n",@difflines));
    shift(@lin);
    my %lines = @lin;
    return %lines;
}
#
# PRIVATE METHODS
# Methods taken from commit-email.pl Copyright subversion team
#
sub _read_from_process
{
    unless (@_)
    {
        croak("$0: read_from_process passed no arguments.\n");
    }
    my ($status, @output) = _safe_read_from_pipe(@_);
    if ($status)
    {
        croak("$0: `@_' failed with this output:", @output);
    }
    else
    {
      return @output;
    }
}
sub _safe_read_from_pipe
{
    unless (@_)
    {
        croak("$0: safe_read_from_pipe passed no arguments.\n");
    }

    my $pid = open(SAFE_READ, '-|');
    unless (defined $pid)
    {
        die "$0: cannot fork: $!\n";
    }
    unless ($pid)
    {
        open(STDERR, ">&STDOUT") or die "$0: cannot dup STDOUT: $!\n";
        exec(@_)or die "$0: cannot exec `@_': $!\n";
    }
    my @output;
    while (<SAFE_READ>)
    {
        s/[\r\n]+$//;
        push(@output, $_);
    }
    close(SAFE_READ);
    my $result = $?;
    my $exit   = $result >> 8;
    my $signal = $result & 127;
    my $cd     = $result & 128 ? "with core dump" : "";
    if ($signal or $cd)
    {
        warn "$0: pipe from `@_' failed $cd: exit=$exit signal=$signal\n";
    }
    if (wantarray)
    {
        return ($result, @output);
    }
    else
    {
        return $result;
    }
}
1;

__END__

=head1 AUTHOR

Salvatore E ScottoDiLuzio, <sal.scotto@gmail.com>

=head1 COPYRIGHT

Copyright 2004 Salvatore E. ScottoDiLuzio.  All Rights Reserved.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
