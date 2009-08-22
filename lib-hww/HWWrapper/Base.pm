package HWWrapper::Base;

use strict;
use warnings;
use utf8;

our $VERSION = "1.5.2";

# import builtin func's hooks
use HWWrapper::Hook::BuiltinFunc;

# import all util commands!!
use HWWrapper::Functions;


use POSIX ();
use Getopt::Long ();
use List::MoreUtils qw(uniq);
use File::Basename qw(basename);
use Digest::MD5 qw(md5_base64);
use IO::Prompt qw(prompt);
use HTTP::Request::Common ();
use List::MoreUtils ();

# require OO modules.
# (derived modules don't need to require these modules)
use File::Spec;
use File::Basename;
use FileHandle;
use URI;
use HTTP::Cookies;
use LWP::UserAgent;





sub new {
    my $self = shift;

    # make all(HW and HWWrapper) class's accessors.
    #
    # $self->$method
    # is lvalue method and identical to
    # $self->{config}{$method}
    $self->mk_accessors(keys %{ $self->{config} });

    return $self;
}


### util subs (need $self) ###

sub get_entrydate {
    my $self = shift;
    my $path = shift;
    $path = basename($path);

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
        my $FH = FileHandle->new($self->touch_file, 'r') or $self->error(":$!");
        chomp(my $line = <$FH>);
        $FH->close;

        $line;
    };
    unless ($touch_time =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
        $self->error("touch.txt: bad format");
    }
    return {
        year  => $1,
        month => $2,
        day   => $3,
        hour  => $4,
        min   => $5,
        sec   => $6,
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
        $self->debug("get options: ".dumper([keys %$opt]));

        local @ARGV = @$argv;
        my $result = $parser->getoptions(%$opt);

        $self->debug(sprintf '%s -> %s', dumper($argv), dumper([@ARGV]));
        $self->debug("true value options:");
        for (grep { ${ $opt->{$_} } } keys %$opt) {
            $self->debug(sprintf "  [%s]:[%s]",
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
        $self->debug("get options only: ".dumper([keys %$proc_opt]));

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
                $self->debug("restore to args: $opt => ${ $dummy_result->{$opt} }");
                if ($opt =~ s/^((.+)=s)$/$2/) {
                    unshift @$argv, "-$2" => ${ $dummy_result->{$1} };
                }
                else {
                    unshift @$argv, "-$opt";
                }
            }
        }

        return $result;
    }
}

sub arg_error {
    my $self = shift;
    my $cmdname = shift;

    unless (defined $cmdname) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = basename($filename);
        $self->debug("arg_error: called at $filename line $line");

        $subname =~ s/.*:://;    # delete package's name
        ($cmdname = $subname) =~ s/_/-/g;    # TODO search $subname in %HWWrapper::Commands::HWW_COMMAND
    }

    # print "error: " string to STDERR.
    eval {
        $self->error("$cmdname: arguments error. show ${cmdname}'s help...");
    };
    STDERR->print($@);
    STDERR->flush;

    # stop or sleep.
    if ($self->is_debug) {
        print "press enter to continue...";
        <STDIN>;
    }
    else {
        sleep 1;
    }

    # show help message!
    $self->dispatch('help', [$cmdname]);

    unlink($self->cookie_file);    # delete cookie file when error occured.
    exit -1;
}

sub mk_accessors {
    my $self = shift;
    my $pkg = caller;
    $self->debug("make accessor to $pkg: ".dumper([@_]));

    for my $method (uniq @_) {
        unless (exists $self->{config}{$method}) {
            $self->error("internal error, sorry.: \$self->{config}{$method} does NOT exist!!");
        }

        my $subname = $pkg."::".$method;
        my $coderef = sub : lvalue { shift->{config}{$method} };

        no strict 'refs';
        if (defined &{$subname}) {
            $self->error("internal error, sorry.: $subname is already defined!!");
        }
        *$subname = $coderef;
    }
}


### from HW.pm ###
# (...and original subrontines from hateda loader)

# Login.
sub login {
    my $self = shift;
    return if $self->user_agent;

    $self->user_agent = LWP::UserAgent->new(agent => $self->agent, timeout => $self->timeout);
    $self->user_agent->env_proxy;
    if ($self->http_proxy) {
        $self->user_agent->proxy('http', $self->http_proxy);
        $self->debug("proxy for http: ".$self->http_proxy);
        $self->user_agent->proxy('https', $self->http_proxy);
        $self->debug("proxy for https: ".$self->http_proxy);
    }

    # Ask username if not set.
    unless ($self->username) {
        $self->username = prompt("Username: ", -echo => '');
    }

    # If "cookie" flag is on, and cookie file exists, do not login.
    if (! $self->no_cookie() and -e($self->cookie_file)) {
        $self->debug("Loading cookie jar.");

        $self->cookie_jar = HTTP::Cookies->new;
        $self->cookie_jar->load($self->cookie_file);
        $self->cookie_jar->scan(\&get_rkm);

        $self->debug("\$cookie_jar = " . $self->cookie_jar->as_string);

        puts("Skip login.");

        return;
    }

    # Ask password if not set.
    unless ($self->password) {
        $self->password = prompt("Password: ", -echo => '');
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    my $r; # Response.
    if ($self->enable_ssl) {
        my $diary_url = sprintf '%s/%s/', $self->hatena_url, $self->username;

        $form{backurl} = $diary_url;
        $form{mode} = "enter";
        unless ($self->no_cookie) {
            $form{persistent} = "1";
        }

        puts(sprintf 'Login to %s as %s.',
            $self->hatena_sslregister_url, $form{name});

        $r = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_sslregister_url, \%form)
        );

        $self->debug($r->status_line);

        $self->debug("\$r = " . $r->content());
    }
    else {
        # For older version.

        $self->debug('hatena_url: '.$self->hatena_url);
        puts(sprintf 'Login to %s as %s.', $self->hatena_url, $form{name});
        $r = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_url."/login", \%form)
        );

        $self->debug($r->status_line);

        if (not $r->is_redirect) {
            $self->error("Login: Unexpected response: ", $r->status_line);
        }
    }

    # Check to exist <meta http-equiv="refresh" content="1;URL=..." />
    unless (defined $r->header('refresh')) {
        $self->debug("failed to login. retry...");
        # $username = '';    # needless?
        $self->password = '';
        # Retry to login.
        @_ = ($self);
        goto &login;
    }

    puts("Login OK.");

    $self->debug("Making cookie jar.");

    $self->cookie_jar = HTTP::Cookies->new;
    $self->cookie_jar->extract_cookies($r);
    $self->cookie_jar->save($self->cookie_file);
    $self->cookie_jar->scan(\&get_rkm);

    $self->debug("\$cookie_jar = " . $self->cookie_jar->as_string);
}

# session id for posting.
our $rkm;

# get session id.
sub get_rkm {
    # NOTE: no $self
    my ($version, $key, $val) = @_;
    if ($key eq 'rk') {
        $rkm = md5_base64($val);
    }
}

# Logout.
sub logout {
    my $self = shift;
    return unless $self->user_agent;

    # If "cookie" flag is on, and cookie file exists, do not logout.
    if (! $self->no_cookie() and -e($self->cookie_file)) {
        puts("Skip logout.");
        return;
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    puts(sprintf 'Logout from %s as %s.', $self->hatena_url, $form{name});

    $self->user_agent->cookie_jar($self->cookie_jar);
    my $r = $self->user_agent->get($self->hatena_url."/logout");
    $self->debug($r->status_line);

    if (not $r->is_redirect and not $r->is_success) {
        $self->error("Logout: Unexpected response: ", $r->status_line);
    }

    unlink($self->cookie_file);

    puts("Logout OK.");
}

# Update entry.
sub update_diary_entry {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    if ($self->trivial) {
        # clear existing entry. if the entry does not exist, it has no effect.
        $self->doit_and_retry("update_diary_entry: CLEAR.", sub { return $self->post_it($year, $month, $day, "", "", "") });
    }

    # Make empty entry before posting.
    $self->doit_and_retry("update_diary_entry: CREATE.", sub { return $self->create_it($year, $month, $day) });

    # Post.
    $self->doit_and_retry("update_diary_entry: POST.", sub { return $self->post_it($year, $month, $day, $title, $body, $imgfile) });
}

# Delete entry.
sub delete_diary_entry {
    my $self = shift;
    my ($date) = @_;

    # Delete.
    $self->doit_and_retry("delete_diary_entry: DELETE.", sub { return $self->delete_it($date) });
}

# Do the $funcref, and retry if fail.
sub doit_and_retry {
    my $self = shift;
    my ($msg, $funcref) = @_;
    my $retry = 0;
    my $ok = 0;

    while ($retry < 2) {
        $ok = $funcref->();
        if ($ok or $self->no_cookie) {
            last;
        }
        $self->debug($msg);
        unlink($self->cookie_file);
        puts("Old cookie. Retry login.");
        $self->login();
        $retry++;
    }

    if (not $ok) {
        $self->error("try_it: Check username/password.");
    }
}

# Delete.
sub delete_it {
    my $self = shift;
    my ($date) = @_;

    $self->debug($date);

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            # Content_Type => 'form-data',
            Content => [
                mode => "delete",
                date => $date,
                rkm => $rkm,
            ]
        )
    );

    $self->debug($r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        $self->error("Delete: Unexpected response: ", $r->status_line);
    }

    $self->debug("Location: " . $r->header("Location"));

    # Check the result. ERROR if the location ends with the date.
    # (Note that delete error != post error)
    if ($r->header("Location") =~ m(/$date$)) {                    # /)){
        $self->debug("returns 0 (ERROR).");
        return 0;
    }
    else {
        $self->debug("returns 1 (OK).");
        return 1;
    }
}

sub create_it {
    my $self = shift;
    my ($year, $month, $day) = @_;

    $self->debug("$year-$month-$day.");

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                trivial => $self->trivial,
                rkm => $rkm,

                # Important:
                # If (entry does exists) { append empty string (i.e. nop) }
                # If (entry does not exist) { create empty entry }
                title => "",
                body => "",
                date => "",
            ]
        )
    );

    $self->debug($r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        $self->error("Create: Unexpected response: ", $r->status_line);
    }

    $self->debug("Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m(/$year$month$day$)) {          # /)){
        $self->debug("returns 1 (OK).");
        return 1;
    }
    else {
        $self->debug("returns 0 (ERROR).");

        return 0;
    }
}

sub post_it {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    $self->debug("$year-$month-$day.");

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::POST(sprintf('%s/%s/edit', $self->hatena_url, $self->username),
            Content_Type => 'form-data',
            Content => [
                mode => "enter",
                timestamp => $self->get_timestamp(),
                year => $year,
                month => $month,
                day => $day,
                title => $title,
                trivial => $self->trivial,
                rkm => $rkm,

                # Important:
                # This entry must already exist.
                body => $body,
                date => "$year$month$day",
                image => [
                    $imgfile,
                ]
            ]
        )
    );

    $self->debug($r->status_line);

    if (not $r->is_redirect) {
        $self->error("Post: Unexpected response: ", $r->status_line);
    }

    $self->debug("Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m{/$year$month$day$}) {
        $self->debug("returns 1 (OK).");
        return 1;
    }
    else {
        $self->debug("returns 0 (ERROR).");
        return 0;
    }
}

# Get "YYYYMMDDhhmmss" for now.
sub get_timestamp {
    my $self = shift;
    my (@week) = qw(Sun Mon Tue Wed Thu Fri Sat);
    my ($sec, $min, $hour, $day, $mon, $year, $weekday) = localtime(time);
    $year += 1900;
    $mon++;
    $mon = "0$mon" if $mon < 10;
    $day = "0$day" if $day < 10;
    $hour = "0$hour" if $hour < 10;
    $min = "0$min" if $min < 10;
    $sec = "0$sec" if $sec < 10;
    $weekday = $week[$weekday];
    return "$year$mon$day$hour$min$sec";
}

# Read title and body.
sub read_title_body {
    my $self = shift;
    my ($file) = @_;

    # Execute filter command, if any.
    my $input = $file;
    if ($self->filter_command) {
        $input = sprintf($self->filter_command." |", $file);
    }
    $self->debug("input: $input");
    my $FILE;
    if (not open($FILE, '<', $input)) {
        $self->error("$!:$input");
    }
    my $title = <$FILE>; # first line.
    chomp($title);
    my $body = join('', <$FILE>); # rest of all.
    close($FILE);

    # Convert encodings.
    if ($self->enable_encode and ($self->client_encoding ne $self->server_encoding)) {
        $self->debug(sprintf 'Convert from %s to %s.',
                $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->client_encoding, $self->server_encoding);
        Encode::from_to($body, $self->client_encoding, $self->server_encoding);
    }

    return($title, $body);
}

# Find image file.
sub find_image_file {
    my $self = shift;
    my ($fulltxt) = @_;
    my ($base, $path, $type) = fileparse($fulltxt, qr/\.txt/);
    for my $ext ('jpg', 'png', 'gif') {
        my $imgfile = "$path$base.$ext";
        if (-e $imgfile) {
            if ($self->target_file) {
                $self->debug("-f option, always update: $imgfile");
                return $imgfile;
            }
            elsif (-e($self->touch_file) and (-M($imgfile) > -M($self->touch_file))) {
                $self->debug("skip $imgfile (not updated).");
                next;
            }
            else {
                $self->debug($imgfile);
                return $imgfile;
            }
        }
    }
    return undef;
}

# Replace "*t*" with timestamp.
sub replace_timestamp {
    my $self = shift;
    my ($filename) = @_;

    # Read.
    my $FILE;
    open($FILE, '<', $filename) or $self->error("$!: $filename");
    my $file = join('', <$FILE>);
    close($FILE);

    # Replace.
    my $newfile = $file;
    $newfile =~ s/^\*t\*/"*" . time() . "*"/gem;

    # Write if replaced.
    if ($newfile ne $file) {
        $self->debug($filename);
        open($FILE, '>', $filename) or $self->error("$!: $filename");
        print $FILE $newfile;
        close($FILE);
    }
}

# Load entry.
sub load_diary_entry {
    my $self = shift;
    my ($year, $month, $day) = @_;

    $self->debug(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day);

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::GET(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day));

    $self->debug($r->status_line);

    if (not $r->is_success()) {
        $self->error("Load: Unexpected response: ", $r->status_line);
    }

    # Check entry exist.
    $r->content =~ /<form .*?action="\.\/edit" .*?>(.*<\/textarea>)/s;
    my $form_data = $1;

    $form_data =~ /<input type="hidden" name="date" value="(\d\d\d\d\d\d\d\d)">/;
    my $resp_date = $1;

    if($resp_date ne "$year$month$day") {
        $self->error("Load: Not exist entry.");
    }

    # Get title and body.
    my $title = "";
    if ($form_data =~ /<input name="title" .*?value="(.*?)"/) {
        $title = $1;
    }
    $form_data =~ /<textarea .*?>(.*?)<\/textarea>/s;
    my $body = $1;

    # Unescape string.
    $title = $self->unescape($title);
    $body = $self->unescape($body);

    # Convert encodings.
    if ($self->enable_encode and ($self->client_encoding ne $self->server_encoding)) {
        $self->debug(sprintf 'Convert from %s to %s.', $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->server_encoding, $self->client_encoding);
        Encode::from_to($body, $self->server_encoding, $self->client_encoding);
    }

    $self->debug("OK");
    return ($title, $body);
}

# return entry's path,
# even if specified entry does not exist.
sub get_entrypath {
    my $self = shift;
    my ($year, $month, $day, $headlines) = @_;
    $headlines = [] unless defined $headlines;

    # find entry.
    for my $path ($self->get_entries($self->txt_dir)) {
        my $info = $self->get_entrydate($path);
        return $path
            if $info->{year} eq $year
            && $info->{month} eq $month
            && $info->{day} eq $day;
    }

    # not found entry's path.
    my $filename = $self->cat_date($year, $month, $day).join('-', @$headlines).'.txt';
    return File::Spec->catfile($self->txt_dir, $filename);
}

sub save_diary_entry {
    my $self = shift;
    my ($year, $month, $day, $title, $body);
    my $filename;
    if (ref $_[0] eq 'HASH') {
        # New way of passing arguments.
        # this can take 'headlines' option additionally.
        my %opt = %{ shift() };
        ($year,$month,$day,$title,$body) = @opt{qw(year month day title body)};
        $filename = $self->get_entrypath($year, $month, $day, exists $opt{headlines} ? $opt{headlines} : undef);
    }
    else {
        # Original way of passing arguments.
        ($year,$month,$day,$title,$body) = @_;
        $filename = $self->get_entrypath($year, $month, $day);
    }


    my $OUT;
    if (not open($OUT, '>', $filename)) {
        $self->error("$!:$filename");
    }
    print $OUT $title."\n";
    print $OUT $body;
    close($OUT);
    $self->debug("wrote $filename");
    return 1;
}

sub unescape {
    my $self = shift;
    my ($str) = @_;
    my @escape_string = (
        "&lt;<",
        "&gt;>",
        "&quot;\"",
        "&nbsp; ",
    );

    for(@escape_string) {
        my ($from, $to) = split(/;/);
        $str =~ s/$from;/$to/sg;
    }

    $str =~ s/&#(\d+);/chr($1)/seg;
    $str =~ s/&amp;/&/sg;

    return $str;
}

# wsse authetication
sub get_wsse_header {
    my $self = shift;
    my ($user, $pass) = ($self->username, $self->password);

    $self->require_modules(qw(
        Digest::SHA1
        MIME::Base64
    ));

    my $sha1 = \&Digest::SHA1::sha1;
    my $encode_base64 = \&MIME::Base64::encode_base64;

    my $nonce = $sha1->($sha1->(time() . {} . rand() . $$));
    my $now = do {
        my ($year, $month, $day, $hour, $min, $sec) = (localtime)[5, 4, 3, 2, 1, 0];
        $year += 1900;
        $month++;
        join('-', $year, $month, $day).'T'.join(':', $hour, $min, $sec).'Z';
    };
    my $digest = $encode_base64->($sha1->($nonce . $now . $pass || ''), '');
    return sprintf(
        q(UsernameToken Username="%s", PasswordDigest="%s", Nonce="%s", Created="%s"),
                                $user, $digest,  $encode_base64->($nonce, ''), $now
    );
}


# from HWWrapper::Functions

sub warning {
    my $self = shift;

    # TODO stash debug value in $self
    if ($self->is_debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        warn "warning: $subname()  at $filename line $line:", @_, "\n";
    }
    else {
        warn "warning: ", @_, "\n";
    }
}

sub error {
    my $self = shift;
    my @errmsg;

    # TODO stash debug value in $self
    if ($self->is_debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        @errmsg = ("error: $subname() at $filename line $line:", @_, "\n");
    }
    else {
        @errmsg = ("error: ", @_, "\n");
    }

    unlink($self->cookie_file);    # from HW::error_exit()
    die @errmsg;
}

sub debug {
    my $self = shift;
    my $subname = (caller 1)[3];
    $self->{debug_fh}->print("debug: $subname(): ", @_, "\n");
}

sub require_modules {
    my $self = shift;
    my @failed;

    for my $m (@_) {
        eval "require $m";
        if ($@) {
            push @failed, $m;
        }
    }

    if (@failed) {
        my $failed = join ', ', @failed;
        $self->error("you need to install $failed.");
    }

    $self->debug("required ".join(', ', @_));
}

# separate options into hww.pl's options and hw.pl's options.
# (like git)
sub split_opt {
    my $self = shift;
    my @hww_opt;
    my $subcmd;
    my @tmp_argv = @_;

    while (defined(my $a = shift)) {
        if ($a =~ /^-/) {
            push @hww_opt, $a;
        }
        else {
            $subcmd = $a;    # found command
            last;
        }
    }

    my @ret = (\@hww_opt, $subcmd, [@_]);
    $self->debug(sprintf "%s -> (%s, %s, %s)\n",
                    dumper(\@tmp_argv),
                    dumper($ret[0]),
                    dumper($ret[1]),
                    dumper($ret[2]));

    # set to $self->{args}{options, command, command_args}.
    @{ $self->{args} }{qw(options command command_args)} = @ret;

    return @ret;
}

# TODO
# - pipe
# - runnning background
#
# FIXME UTF8以外の環境だとMalformed UTF-8 characterと出る
#
# NOTE:
# pass "complete command line string".
# DON'T pass incomplete string. e.g.: "right double quote missing
sub shell_eval_str {
    my $self = shift;
    my $line = shift;
    my @args;

    if ($line =~ /\n/m) {
        Carp::croak "give me the string line which does NOT contain newline!";
    }

    my $push_new_args = sub {
        $self->debug("push new args!:[%s]", join ', ', @_);
        push @args, [@_];
    };
    my $push_args = sub {
        Carp::croak "push_args: receive empty args" unless @_;

        if (@args) {
            $self->debug("push args!:[%s]", join ', ', @_);
            push @{ $args[-1] }, @_;
        }
        else {
            $push_new_args->(@_);
        }
    };


    while (length $line) {
        next if $line =~ s/^ \s+//x;

        if ($line =~ /^"/) {    # double quotes
            my $evaluated = $self->get_quote_str($line, begin => q("), end => q("), eval => 1);
            $line = $evaluated->{rest_str};
            $push_args->($evaluated->{body});
        }
        elsif ($line =~ /^'/) {    # single quotes
            my $got = $self->get_quote_str($line, begin => q('), end => q('));
            $line = $got->{rest_str};
            $push_args->($got->{body});    # push body
        }
        elsif ($line =~ s/^;//) {    # ;
            $push_new_args->();
        }
        elsif ($line =~ s/^([^\s"';]+)//) {    # literal
            # evaluate it.
            $line = (sprintf q("%s"), $1).$line;
        }
        else {    # wtf?
            $self->error("parse error");
        }
    }

    return @args;
}

sub is_complete_str {
    my $self = shift;
    my $line = shift;

    eval {
        $self->shell_eval_str($line)
    };

    if ($@) {
        if ($@ =~ /unexpected end of string while looking for/) {
            return 0;
        }
        else {
            $self->warning("failed to parse cmdline string: ".$@);
        }
    }
    else {
        return 1;
    }
}

sub get_quote_str {
    my $self = shift;
    my $line = shift;

    my %opt = (
        eval => 0,
        @_
    );
    unless (exists $opt{begin} && exists $opt{end}) {
        Carp::croak "give me options 'begin' and 'end' at least!";
    }

    my ($lquote, $rquote) = @opt{qw(begin end)};
    unless ($line =~ s/^$lquote//) {
        Carp::croak "regex '^$lquote' does not matched to ".dumper($line);
    }

    my $shift_str = sub {
        return undef if length $_[0] == 0;
        my $c = substr $_[0], 0, 1;    # first char
        $_[0] = substr $_[0], 1;       # rest
        return $c;
    };
    my $body = '';
    my $completed;


    while (length $line) {
        my $c = $shift_str->($line);

        if ($c eq $rquote) {    # end of string
            $completed = 1;
            last;
        }
        elsif ($c eq "\\") {    # escape
            if ($opt{eval}) {
                my $ch = $shift_str->($line);
                # unexpected end of string ...
                last unless defined $ch;

                $c = "\\".$ch;
                $body .= eval sprintf q("%s"), $c;
            }
            else {
                $body .= $c;
            }
        }
        else {
            $body .= $c;
        }
    }

    unless ($completed) {
        $self->error("unexpected end of string while looking for $rquote");
    }

    return {
        body => $body,
        rest_str => $line,
    };
}

sub familiar_words {
    my $self = shift;
    my ($word, $words, $opt) = @_;

    return () unless @$words;

    $self->debug(sprintf 'word:[%s], candidates:[%s]', $word, dumper($words));

    %$opt = (diff_strlen => 4, partial_match_len => 4, %$opt);

    my @chars = split //, $word;
    my $last_idx;
    my @familiar;

    # get words which contains same orders chars of $word.
    for my $w (@$words) {
        $last_idx = 0;
        # push its word.
        push @familiar, $w
            # if $w contains all chars of $word.
            # (and chars orders are the same)
            if List::MoreUtils::all {
                ($last_idx = index($w, $_, $last_idx)) != -1
            } @chars;
    }


    if (length($word) >= $opt->{partial_match_len}) {
        # get words which contain $word.
        @familiar = grep {
            index($_, $word) != -1
        } @familiar;
    }
    else {
        # different string length is lower than diff_strlen.
        @familiar = grep {
            abs(length($_) - length($word)) < $opt->{diff_strlen}
        } @familiar;
    }


    return @familiar;
}


# TODO 日付関連のテスト

# split 'date'.
#
# NOTE:
# $self->get_entrydate() takes path,
# and returns undef or hash reference.
sub split_date {
    my $self = shift;
    my $date = shift;

    if ($date =~ /\A(\d{4})-(\d{2})-(\d{2})(?:-.+)?(?:\.txt)?\Z/) {
        return ($1, $2, $3);
    }
    else {
        $self->error("$date: Illegal date format.");
    }
}

# concat 'date'.
sub cat_date {
    my $self = shift;
    my ($year, $month, $day, $headlines) = @_;

    # concat ymd.
    my $datename = sprintf '%04d-%02d-%02d', $year, $month, $day;
    # concat headlines
    $datename .= defined $headlines ? '-'.join('-', @$headlines) : '';

    return $datename;
}




1;
