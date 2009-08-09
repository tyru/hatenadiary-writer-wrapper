package HWWrapper::UtilSub;

use strict;
use warnings;
use utf8;

our $VERSION = "1.0.7";

# import all util commands!!
use HWWrapper::UtilSub::Functions;


use FileHandle ();
use POSIX ();
use Getopt::Long ();
use List::MoreUtils qw(uniq);





### util subs (need $self) ###

sub get_entrydate {
    my $self = shift;
    my $path = shift;
    $path = File::Basename::basename($path);

    # $path might be html file.
    if ($path =~ /\A(\d{4})-(\d{2})-(\d{2})(-[\w\W]+)?\.(html|txt)\Z/m) {
        return {
            year  => $1,
            month => $2,
            day   => $3,
            rest  => $4,
        };
    }
    else {
        return undef;
    }
}

sub find_headlines {
    my $self = shift;
    my ($body) = @_;
    my @headline;

    # NOTE: all headlines are replaced with ' '.
    # because '*headlines**not headlines*' are allowed
    # if headlines were replaced with ''.
    while ($body =~ s/^\*([^\n\*]+)\*/ /m) {
        push @headline, $1;
    }
    return @headline;
}

sub get_entries {
    my $self = shift;
    my ($dir, $fileglob) = @_;

    # set default value.
    $dir      = $self->txt_dir unless defined $dir;
    $fileglob = '*.txt'      unless defined $fileglob;

    grep {
        -e $_ && -f _
    } grep {
        defined $self->get_entrydate($_)
    } glob "$dir/$fileglob"
}

sub get_entries_hash {
    my $self = shift;
    my @entries = $self->get_entries(@_);
    my %hash;
    for my $date (map { $self->get_entrydate($_) } @entries) {
        my $ymd = join '-', @$date{qw(year month day)};
        $hash{$ymd} = $date;
    }
    %hash;
}

sub get_updated_entries {
    my $self = shift;

    grep {
        (-e $_ && -e $self->touch_file)
        && -M $_ < -M $self->touch_file
    } $self->get_entries(@_);
}


# get misc info about time from 'touch.txt'.
# NOTE: unused
sub get_touchdate {
    my $self = shift;

    my $touch_time = do {
        my $FH = FileHandle->new($self->touch_file, 'r') or error(":$!");
        chomp(my $line = <$FH>);
        $FH->close;

        $line;
    };
    unless ($touch_time =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
        error("touch.txt: bad format");
    }
    return {
        year => $1,
        month => $2,
        day => $3,
        hour => $4,
        min => $5,
        sec => $6,
        epoch => POSIX::mktime($6, $5, $4, $3, $2-1, $1-1900),
    };
}

{
    # gnu_compat: --opt="..." is allowed.
    # no_bundling: single character option is not bundled.
    # no_auto_abbrev: single character option is not bundled.(which?)
    # no_ignore_case: no ignore case on long option.
    my $parser = Getopt::Long::Parser->new(
        config => [qw(
            gnu_compat
            no_bundling
            no_auto_abbrev
            no_ignore_case
        )]
    );

    # Usage: $self->get_opt([...], {...});
    sub get_opt {
        my $self = shift;
        my ($argv, $opt) = @_;

        return 1 unless @$argv;
        debug("get options: ".dumper([keys %$opt]));

        local @ARGV = @$argv;
        my $result = $parser->getoptions(%$opt);

        debug(sprintf '%s -> %s', dumper($argv), dumper([@ARGV]));
        debug("true value options:");
        for (grep { ${ $opt->{$_} } } keys %$opt) {
            debug(sprintf "  [%s]:[%s]",
                            $_, ${ $opt->{$_} });
        }

        # update arguments. delete all processed options.
        @$argv = @ARGV;
        return $result;
    }

    # $self->get_opt_only(
    #     \@ARGV,    # in this arguments
    #     { a => \my $a, ... },    # get only these options
    # );
    # if ($a) { print "option '-a' was given!!\n" }
    #
    # Usage: $self->get_opt_only([...], {...})
    sub get_opt_only {
        my $self = shift;
        my ($argv, $proc_opt) = @_;

        return 1 unless @$argv;
        debug("get options only: ".dumper([keys %$proc_opt]));

        # cache
        $self->{arg_opt}{all_opt_cache} ||= [
            map {
                keys %$_
            } ($self->{arg_opt}{HWWrapper}, $self->{arg_opt}{HW})
        ];
        my $all_opt = $self->{arg_opt}{all_opt_cache};

        # get options
        my $dummy_result = {map { $_ => \my $o } @$all_opt};
        my $result = $self->get_opt($argv, $dummy_result);

        # restore all results except $proc_opt
        # NOTE: parsing only $proc_opt in $argv is bad.
        # because it's difficult to parse $argv 'exactly'.
        # so let get_opt() parse it.
        for my $opt (keys %$dummy_result) {
            # option was not given
            next unless defined ${ $dummy_result->{$opt} };

            if (exists $proc_opt->{$opt}) {
                # apply values
                ${ $proc_opt->{$opt} } = ${ $dummy_result->{$opt} };
            }
            else {
                # don't apply value and restore it to $argv
                debug("restore to args: $opt => ${ $dummy_result->{$opt} }");
                if ($opt =~ s/^((.+)=s)$/$2/) {
                    unshift @$argv, "-$2" => ${ $dummy_result->{$1} };
                } else {
                    unshift @$argv, "-$opt";
                }
            }
        }

        return $result;
    }
}

sub arg_error {
    my $self = shift;
    my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
    $filename = File::Basename::basename($filename);
    debug("arg_error: called at $filename line $line");

    $subname =~ s/.*:://;    # delete package's name
    my %rev_dict = reverse %HWWrapper::HWW_COMMAND;
    my $cmdname = $rev_dict{$subname};

    unless (defined $cmdname) {
        # internal error (my mistake...)
        error("can't find ${subname}'s command name");
    }

    # no need to localize $@ though
    # because we are going to die :-)
    local $@;
    eval {
        error("$cmdname: arguments error. show ${cmdname}'s help...");
    };
    warn $@;
    STDERR->flush;

    if ($HWWrapper::debug) {
        print "press enter to continue...";
        <STDIN>;
    }
    else {
        sleep 1;
    }
    $self->dispatch('help', [$cmdname]);

    # from HW::error_exit()
    unlink($self->cookie_file);

    exit -1;
}

sub mk_accessors {
    my $pkg = shift;
    debug("make accessor to $pkg: ".dumper([@_]));

    for my $method (uniq @_) {
        my $subname = $pkg."::".$method;
        my $coderef = sub : lvalue { shift->{config}{$method} };

        no strict 'refs';
        *$subname = $coderef;
    }
}




1;
