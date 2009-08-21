package HWWrapper::Base;

use strict;
use warnings;
use utf8;

our $VERSION = "1.4.1";

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
        my $FH = FileHandle->new($self->touch_file, 'r') or error(":$!");
        chomp(my $line = <$FH>);
        $FH->close;

        $line;
    };
    unless ($touch_time =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
        error("touch.txt: bad format");
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
        debug("arg_error: called at $filename line $line");

        $subname =~ s/.*:://;    # delete package's name
        ($cmdname = $subname) =~ s/_/-/g;    # TODO search $subname in %HWWrapper::Commands::HWW_COMMAND
    }

    # print "error: " string to STDERR.
    eval {
        error("$cmdname: arguments error. show ${cmdname}'s help...");
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
    debug("make accessor to $pkg: ".dumper([@_]));

    for my $method (uniq @_) {
        unless (exists $self->{config}{$method}) {
            error("internal error, sorry.: \$self->{config}{$method} does NOT exist!!");
        }

        my $subname = $pkg."::".$method;
        my $coderef = sub : lvalue { shift->{config}{$method} };

        no strict 'refs';
        if (defined &{$subname}) {
            error("internal error, sorry.: $subname is already defined!!");
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
        debug("proxy for http: ".$self->http_proxy);
        $self->user_agent->proxy('https', $self->http_proxy);
        debug("proxy for https: ".$self->http_proxy);
    }

    # Ask username if not set.
    unless ($self->username) {
        $self->username = prompt("Username: ", -echo => '');
    }

    # If "cookie" flag is on, and cookie file exists, do not login.
    if ($self->use_cookie() and -e($self->cookie_file)) {
        debug("Loading cookie jar.");

        $self->cookie_jar = HTTP::Cookies->new;
        $self->cookie_jar->load($self->cookie_file);
        $self->cookie_jar->scan(\&get_rkm);

        debug("\$cookie_jar = " . $self->cookie_jar->as_string);

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
        if ($self->use_cookie) {
            $form{persistent} = "1";
        }

        puts(sprintf 'Login to %s as %s.',
            $self->hatena_sslregister_url, $form{name});

        $r = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_sslregister_url, \%form)
        );

        debug($r->status_line);

        debug("\$r = " . $r->content());
    }
    else {
        # For older version.

        debug('hatena_url: '.$self->hatena_url);
        puts(sprintf 'Login to %s as %s.', $self->hatena_url, $form{name});
        $r = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_url."/login", \%form)
        );

        debug($r->status_line);

        if (not $r->is_redirect) {
            error("Login: Unexpected response: ", $r->status_line);
        }
    }

    # Check to exist <meta http-equiv="refresh" content="1;URL=..." />
    unless (defined $r->header('refresh')) {
        debug("failed to login. retry...");
        # $username = '';    # needless?
        $self->password = '';
        # Retry to login.
        @_ = ($self);
        goto &login;
    }

    puts("Login OK.");

    debug("Making cookie jar.");

    $self->cookie_jar = HTTP::Cookies->new;
    $self->cookie_jar->extract_cookies($r);
    $self->cookie_jar->save($self->cookie_file);
    $self->cookie_jar->scan(\&get_rkm);

    debug("\$cookie_jar = " . $self->cookie_jar->as_string);
}

# session id for posting.
our $rkm;

# get session id.
sub get_rkm {
    # NOTE: no $self
    my ($version, $key, $val) = @_;
    if ($key eq 'rk') {
        $rkm = md5_base64($val);
        debug("\$rkm = " . $rkm);
    }
}

# Logout.
sub logout {
    my $self = shift;
    return unless $self->user_agent;

    # If "cookie" flag is on, and cookie file exists, do not logout.
    if ($self->use_cookie() and -e($self->cookie_file)) {
        puts("Skip logout.");
        return;
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    puts(sprintf 'Logout from %s as %s.', $self->hatena_url, $form{name});

    $self->user_agent->cookie_jar($self->cookie_jar);
    my $r = $self->user_agent->get($self->hatena_url."/logout");
    debug($r->status_line);

    if (not $r->is_redirect and not $r->is_success) {
        error("Logout: Unexpected response: ", $r->status_line);
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
        if ($ok or not $self->use_cookie) {
            last;
        }
        debug($msg);
        unlink($self->cookie_file);
        puts("Old cookie. Retry login.");
        $self->login();
        $retry++;
    }

    if (not $ok) {
        error("try_it: Check username/password.");
    }
}

# Delete.
sub delete_it {
    my $self = shift;
    my ($date) = @_;

    debug($date);

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

    debug($r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        error("Delete: Unexpected response: ", $r->status_line);
    }

    debug("Location: " . $r->header("Location"));

    # Check the result. ERROR if the location ends with the date.
    # (Note that delete error != post error)
    if ($r->header("Location") =~ m(/$date$)) {                    # /)){
        debug("returns 0 (ERROR).");
        return 0;
    }
    else {
        debug("returns 1 (OK).");
        return 1;
    }
}

sub create_it {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug("$year-$month-$day.");

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

    debug($r->status_line);

    if ((not $r->is_redirect()) and (not $r->is_success())) {
        error("Create: Unexpected response: ", $r->status_line);
    }

    debug("Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m(/$year$month$day$)) {          # /)){
        debug("returns 1 (OK).");
        return 1;
    }
    else {
        debug("returns 0 (ERROR).");

        return 0;
    }
}

sub post_it {
    my $self = shift;
    my ($year, $month, $day, $title, $body, $imgfile) = @_;

    debug("$year-$month-$day.");

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

    debug($r->status_line);

    if (not $r->is_redirect) {
        error("Post: Unexpected response: ", $r->status_line);
    }

    debug("Location: " . $r->header("Location"));

    # Check the result. OK if the location ends with the date.
    if ($r->header("Location") =~ m{/$year$month$day$}) {
        debug("returns 1 (OK).");
        return 1;
    }
    else {
        debug("returns 0 (ERROR).");
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
    debug("input: $input");
    my $FILE;
    if (not open($FILE, '<', $input)) {
        error("$!:$input");
    }
    my $title = <$FILE>; # first line.
    chomp($title);
    my $body = join('', <$FILE>); # rest of all.
    close($FILE);

    # Convert encodings.
    if ($self->enable_encode and ($self->client_encoding ne $self->server_encoding)) {
        debug(sprintf 'Convert from %s to %s.',
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
                debug("-f option, always update: $imgfile");
                return $imgfile;
            }
            elsif (-e($self->touch_file) and (-M($imgfile) > -M($self->touch_file))) {
                debug("skip $imgfile (not updated).");
                next;
            }
            else {
                debug($imgfile);
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
    open($FILE, '<', $filename) or error("$!: $filename");
    my $file = join('', <$FILE>);
    close($FILE);

    # Replace.
    my $newfile = $file;
    $newfile =~ s/^\*t\*/"*" . time() . "*"/gem;

    # Write if replaced.
    if ($newfile ne $file) {
        debug($filename);
        open($FILE, '>', $filename) or error("$!: $filename");
        print $FILE $newfile;
        close($FILE);
    }
}

# Load entry.
sub load_diary_entry {
    my $self = shift;
    my ($year, $month, $day) = @_;

    debug(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day);

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::GET(sprintf '%s/%s/edit?date=%s%s%s', $self->hatena_url, $self->username, $year, $month, $day));

    debug($r->status_line);

    if (not $r->is_success()) {
        error("Load: Unexpected response: ", $r->status_line);
    }

    # Check entry exist.
    $r->content =~ /<form .*?action="\.\/edit" .*?>(.*<\/textarea>)/s;
    my $form_data = $1;

    $form_data =~ /<input type="hidden" name="date" value="(\d\d\d\d\d\d\d\d)">/;
    my $resp_date = $1;

    if($resp_date ne "$year$month$day") {
        error("Load: Not exist entry.");
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
        debug(sprintf 'Convert from %s to %s.', $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->server_encoding, $self->client_encoding);
        Encode::from_to($body, $self->server_encoding, $self->client_encoding);
    }

    debug("OK");
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
    my $filename = cat_date($year, $month, $day).join('-', @$headlines).'.txt';
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
        error("$!:$filename");
    }
    print $OUT $title."\n";
    print $OUT $body;
    close($OUT);
    debug("wrote $filename");
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

    require_modules(qw(
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




1;
