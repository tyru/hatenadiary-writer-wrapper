package HWW;

use strict;
use warnings;
use utf8;

use version;
our $VERSION = qv('0.0.2');

use File::Spec;
use Pod::Usage;


our %HWW_COMMAND = (
    help => \&help,
    version => \&version,
    release => \&release,
    update => \&update,
    load => \&load,
);



### util commands ###

sub warning {
    warn "warning: ", @_, "\n";
}

sub error {
    die "error: ", @_, "\n";
}

sub debug {
    warn "debug: ", @_, "\n" if $hww_main::debug;
}

sub is_hww_command {
    my ($self, $cmd) = @_;
    $self->can($cmd) && exists $HWW_COMMAND{$cmd};
}

sub sub_alias {
    my ($to, $from) = @_;
    no strict 'refs';
    *$to = $from;
}

sub_alias getopt => \&hww_main::getopt;

sub call_hw {
    my ($self, @args) = @_;
    my $hw = File::Spec->catfile($hww_main::BASE_DIR, 'hw.pl');
    my @debug = $hww_main::debug ? qw(-d) : ();
    system 'perl', $hw, @debug, @args;
}

sub require_modules {
    my @modules = @_;
    for my $m (@modules) {
        eval "require $m";
        if ($@) {
            error("you need to install $m.");
        }
    }
}



### dispatch ###

sub dispatch {
    my ($self, $cmd, $args) = @_;

    $self = bless {}, $self;

    unless ($self->is_hww_command($cmd)) {
        error("'$cmd' is not a hww-command. See perl $0 help");
    }

    debug("dispatch $cmd");
    $self->$cmd(@$args);
}



### hww commands ###

sub help {
    my ($self, $cmd) = @_;

    unless (defined $cmd) {
        debug("show HWW.pm pod");
        pod2usage(-verbose => 2, -input => __FILE__);
    }

    unless ($self->is_hww_command($cmd)) {
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
    $self->call_hw('-c');
}

sub update {
    my $self = shift;
    $self->call_hw('-c', '-t');
}

sub load {
    my $self = shift;

    my $all;
    getopt(\@_, {
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
        $self->call_hw('-c', '-l', $ymd);
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
