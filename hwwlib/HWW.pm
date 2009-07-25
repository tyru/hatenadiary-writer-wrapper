package HWW;

use strict;
use warnings;
use utf8;

use version;
our $VERSION = qv('0.0.4');

use File::Spec;
use Pod::Usage;
use File::Basename;


our %HWW_COMMAND = (
    help => \&help,
    version => \&version,
    release => \&release,
    update => \&update,
    load => \&load,
    verify => \&verify,
);




### util commands ###

sub warning {
    warn "warning: ", sprintf(@_), "\n";
}

sub error {
    die "error: ", sprintf(@_), "\n";
}

sub debug {
    warn "debug: ", @_, "\n" if $hww_main::debug;
}

# not 'say'.
# but print with newline.
sub puts {
    print @_, "\n";
}

sub is_hww_command {
    my $cmd = shift;
    __PACKAGE__->can($cmd) && exists $HWW_COMMAND{$cmd};
}

sub sub_alias {
    my ($to, $from) = @_;
    no strict 'refs';
    *$to = $from;
}

sub_alias getopt => \&hww_main::getopt;

sub call_hw {
    my $hw = File::Spec->catfile($hww_main::BASE_DIR, 'hw.pl');
    my @debug = $hww_main::debug ? qw(-d) : ();
    system 'perl', $hw, @debug, @_;
}

sub require_modules {
    my @failed;
    for my $m (@_) {
        eval "require $m";
        if ($@) {
            push @failed, $m;
        }
    }
    if (@failed) {
        error("you need to install %s.", join(', ', @failed));
    }
}

sub get_entrydate {
    my $path = shift;

    if (basename($path) =~ /\A(\d{4})-(\d{2})-(\d{2})(-.+).txt?\Z/) {
        return {
            year  => $1,
            month => $2,
            day   => $3,
            rest  => $4,
        };
    } else {
        return undef;
    }
}



### dispatch ###

sub dispatch {
    my ($self, $cmd, $args) = @_;

    $self = bless {}, $self;

    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    debug("dispatch '$cmd'");
    $self->$cmd($args);
}



### hww commands ###

sub help {
    my ($self, $args) = @_;
    my $cmd = exists $args->[0] ? $args->[0] : undef;

    unless (defined $cmd) {
        debug("show HWW.pm pod");
        pod2usage(-verbose => 2, -input => __FILE__);
    }

    unless (is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    my $podpath = File::Spec->catdir($hww_main::HWW_LIB, 'pod', "hww-$cmd.pod");
    unless (-f $podpath) {
        error("we have not written the document of '$cmd' yet. :$!");
    }

    debug("show pod '$podpath'");
    pod2usage(-verbose => 2, -input => $podpath);
}

sub version {
    print <<EOD;
Hatena Diary Writer Wrapper version $HWW::VERSION
EOD
    exit;
}

sub release {
    my $self = shift;
    call_hw('-c');
}

sub update {
    my $self = shift;
    $self->release(@_);
}

sub load {
    my ($self, $args) = @_;

    my $all;
    getopt($args, {
        all => \$all,
    }) or error("load: arguments error");

    if ($all) {
        require_modules(qw(XML::TreePP));

        package hw_main;

        # import and declare package global variables.
        our $user_agent;
        our $cookie_jar;
        our $hatena_url;
        our $username;


        # Login if necessary.
        login() unless ($user_agent);

        $user_agent->cookie_jar($cookie_jar);

        my $export_url = "$hatena_url/$username/export";
        print_debug("GET $export_url");
        my $r = $user_agent->simple_request(
            HTTP::Request::Common::GET($export_url)
        );

        unless ($r->is_success) {
            die "couldn't get entries:".$r->status_line;
        }

        my $xml_parser = XML::TreePP->new;
        my $entries = $xml_parser->parse($r->content);

        for my $entry (@{ $entries->{diary}{day} }) {
            my ($year, $month, $day);
            if ($entry->{'-date'} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
                ($year, $month, $day) = ($1, $2, $3);
            } else {
                error_exit($entry->{'-date'}." is invalid format. (format: YYYY-MM-DD)");
            }

            save_diary_entry($year, $month, $day, $entry->{'-title'}, $entry->{body});
        }

        logout() if ($user_agent);

    } else {
        my $ymd = shift || $self->dispatch('help', 'load');
        call_hw('-c', '-l', $ymd);
    }
}

# currently only checking duplicated entries.
sub verify {
    my $self = shift;

    my $txt_dir = do {
        package hw_main;
        # import package global variables.
        our $txt_dir;
    };


    # check if a entry duplicates other entries.
    my %entry;
    my @duplicated;
    for my $file (map { basename $_ } glob "$txt_dir/*.txt") {
        my $date = get_entrydate($file);
        next    unless defined $date;

        my $ymd = sprintf "%s-%s-%s",
                            $date->{year},
                            $date->{month},
                            $date->{day};
        if (exists $entry{$ymd}) {
            debug("$file is duplicated.");
            push @duplicated, [$ymd, $file];
        } else {
            $entry{$ymd} = $file;
        }
    }

    if (@duplicated) {
        puts("duplicated entries here:");
        for (@duplicated) {
            # dulicated entry which was found at first
            puts("  $entry{$_->[0]}");
            # filepath
            puts("  $_->[1]");
        }
    } else {
        puts("ok: not found any bad conditions.");
    }
}


1;
__END__

=head1 NAME

    hww.pl - Hatena Diary Writer Wrapper


=head1 SYNOPSIS

    $ perl hww.pl [OPTIONS] COMMAND [ARGS]


=head1 OPTIONS

    these options for 'hww.pl'.
    if you see the help of command options, do it.
    $ perl hww.pl help <command>

=over

=item -h,--help

show this help text.

=item -v,--version

show version.

=back


=head1 AUTHOR

tyru <tyru.exe@gmail.com>
