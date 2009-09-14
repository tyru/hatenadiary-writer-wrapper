package HWWrapper::Base;

use strict;
use warnings;
use utf8;

# import all util commands!!
use HWWrapper::Functions;
use HWWrapper::Commands;


use Carp;
use POSIX ();
use Getopt::Long ();
use List::Util ();
use List::MoreUtils ();
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

    # make all(HW and HWWrapper) class's accessors to this package.
    $self->mk_accessors(
        [keys %{ $self->{config} }],
        $self->{config},
        {lvalue => 1}
    );
    $self->mk_accessors(
        [keys %{ $self->{config_file_immutable_ac} }],
        $self->{config_file_immutable_ac},
        {lvalue => 1}
    );

    return $self;
}


### util subs (need $self) ###

sub get_entrydate {
    my ($self, $path) = @_;
    my @allowed_ext = qw(.txt .htm .html .jpg .gif .png);
    my ($base, $dir, $ext) = fileparse($path, @allowed_ext);

    # not allowed ext
    return undef if $ext eq '';

    $path = $base . $ext;
    # delete '.', join with '|'.
    my $allowed_ext = join '|', map { substr $_, 1 } @allowed_ext;

    # $path might be html file.
    if ($path =~ /\A(\d{4})-(\d{2})-(\d{2}) (-[\w\W]+)? \.($allowed_ext)\Z/mx) {
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
    my ($self, $dir, $fileglob) = @_;

    # set default value.
    $dir      = $self->txt_dir unless defined $dir;
    $fileglob = '*.txt'      unless defined $fileglob;

    grep {
        -e $_ && -f _
    } grep {
        defined $self->get_entrydate($_)
    } glob "$dir/$fileglob"
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
        my $FH = FileHandle->new($self->touch_file, 'r')
                    or $self->error($self->touch_file.": $!");
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

sub update_touch_file {
    my ($self) = @_;

    my $FH = FileHandle->new($self->touch_file, 'w')
                or $self->error($self->touch_file.": $!");
    $FH->print($self->get_timestamp);
    $FH->close;
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

        if ($self->is_debug) {
            $self->debug(sprintf '%s -> %s', dumper($argv), dumper([@ARGV]));
        }

        # update arguments. delete all processed options.
        @$argv = @ARGV;
        return $result;
    }
}

sub arg_error {
    my ($self) = @_;
    $self->error("arguments error. see the help.");
}

# @_: [methods, ...], {this value's lvalue accessor}, {options}
# Note that $hashref must NOT be temporary hash reference.
sub mk_accessors {
    my ($self, $methods, $hashref, $opt) = @_;

    $opt = {} unless defined $opt;
    %$opt = (
        lvalue => 0,
        %$opt
    );

    for my $method (@$methods) {
        unless (exists $hashref->{$method}) {
            $self->error("internal error, sorry.: \$hashref->{$method} does NOT exist!!");
        }

        my $subname = "HWWrapper::Base::$method";
        my $coderef;
        if ($opt->{lvalue}) {
            $coderef = sub : lvalue { $hashref->{$method} };
        } else {
            $coderef = sub { $hashref->{$method} };
        }

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
    my %opt = (
        force => 0,
        @_
    );
    local $self->{config}{use_cookie} = $opt{force} ? 0 : $self->{config}{use_cookie};
    if ($opt{force}) {
        $self->user_agent = undef;
        $self->username = '';
        $self->password = '';
    }

    if (defined $self->user_agent) {
        $self->debug("already logged in.");
        return 1;
    }

    $self->user_agent = LWP::UserAgent->new(agent => $self->agent, timeout => $self->timeout);
    $self->user_agent->env_proxy;
    if ($self->http_proxy) {
        $self->user_agent->proxy('http', $self->http_proxy);
        $self->debug("proxy for http: ".$self->http_proxy);
        $self->user_agent->proxy('https', $self->http_proxy);
        $self->debug("proxy for https: ".$self->http_proxy);
    }

    # Ask username if not set.
    unless (length $self->username) {
        print "Username: ";
        chomp($self->username = <STDIN>);
    }

    # If "cookie" flag is on, and cookie file exists, do not login.
    if ($self->use_cookie() && -e($self->cookie_file)) {
        $self->debug("Loading cookie jar.");

        $self->cookie_jar = HTTP::Cookies->new;
        $self->cookie_jar->load($self->cookie_file);
        $self->cookie_jar->scan(\&get_rkm);

        $self->debug("\$cookie_jar = " . $self->cookie_jar->as_string);

        puts("Skip login.");

        # though I don't know if the cookie is correct.
        return;
    }

    # Ask password if not set.
    unless (length $self->password) {
        if ($self->dont_show_password) {
            $self->require_modules(qw(IO::Prompt));
            $self->password = IO::Prompt::prompt("Password: ", -echo => '');
        }
        else {
            print "Password: ";
            chomp($self->password = <STDIN>);
        }
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    my $res;
    if ($self->enable_ssl) {
        my $diary_url = sprintf '%s/%s/', $self->hatena_url, $self->username;

        $form{backurl} = $diary_url;
        $form{mode} = "enter";
        if ($self->use_cookie) {
            $form{persistent} = "1";
        }

        puts(sprintf 'Login to %s as %s.',
            $self->hatena_sslregister_url, $form{name});

        $res = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_sslregister_url, \%form)
        );

        $self->debug($res->status_line);
    }
    else {
        # For older version.

        $self->debug('hatena_url: '.$self->hatena_url);
        puts(sprintf 'Login to %s as %s.', $self->hatena_url, $form{name});
        $res = $self->user_agent->simple_request(
            HTTP::Request::Common::POST($self->hatena_url."/login", \%form)
        );

        $self->debug($res->status_line);

        unless ($res->is_redirect) {
            $self->error("Login: Unexpected response: ", $res->status_line);
        }
    }

    $self->debug("Making cookie jar.");

    $self->cookie_jar = HTTP::Cookies->new;
    $self->cookie_jar->extract_cookies($res);
    $self->cookie_jar->save($self->cookie_file);
    $self->cookie_jar->scan(\&get_rkm);

    $self->debug("\$cookie_jar = " . $self->cookie_jar->as_string);


    # unless exist <meta http-equiv="refresh" content="1;URL=..." />,
    # retry to login.
    unless (defined $res->header('refresh')) {
        if ($self->{login_retry_count} >= $self->{config}{login_retry_num}) {
            $self->debug("stop trying to login.");
            $self->error("failed to login.");
        }

        $self->username = '';
        $self->password = '';
        $self->user_agent = undef;

        local $self->{login_retry_count} = $self->{login_retry_count} + 1;
        $self->debug(sprintf "failed to login. retry... (count:%d)",
                             $self->{login_retry_count});
        # Retry to login.
        $self->login;
    }

    puts("Login OK.");
}

{
    # session id for posting.
    my $rkm;

    # get session id.
    # NOTE: no $self
    sub get_rkm {
        if (@_) {
            my ($version, $key, $val) = @_;
            if ($key eq 'rk') {
                $rkm = md5_base64($val);
            }
        }
        return $rkm;
    }
}

# Logout.
sub logout {
    my $self = shift;
    my %opt = (
        force => 0,
        @_
    );
    local $self->{config}{use_cookie} = $opt{force} ? 0 : $self->{config}{use_cookie};

    unless (defined $self->user_agent) {
        $self->debug("already logged out.");
        return;
    }

    # If "cookie" flag is on, and cookie file exists, do not logout.
    if ($self->use_cookie() && -e($self->cookie_file)) {
        puts("Skip logout.");
        return;
    }

    my %form;
    $form{name} = $self->username;
    $form{password} = $self->password;

    puts(sprintf 'Logout from %s as %s.', $self->hatena_url, $form{name});

    $self->user_agent->cookie_jar($self->cookie_jar);
    my $res = $self->user_agent->get($self->hatena_url."/logout");
    $self->debug($res->status_line);

    if (! $res->is_redirect && ! $res->is_success) {
        $self->error("Logout: Unexpected response: ", $res->status_line);
    }

    unlink($self->cookie_file);
    $self->user_agent = undef;

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
    my ($self, $year, $month, $day) = @_;

    my $date = $self->cat_date({
        year => $year,
        month => $month,
        day => $day,
        cat_with => '',
    });

    # Delete.
    $self->doit_and_retry(
        "delete_diary_entry: DELETE.",
        sub { return $self->delete_it($date) }
    );
}

# Do the $funcref, and retry if fail.
sub doit_and_retry {
    my $self = shift;
    my ($msg, $funcref) = @_;
    my $retry = 0;
    my $ok = 0;

    while ($retry < 2) {
        $ok = $funcref->();
        if ($ok or ! $self->use_cookie) {
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
                rkm => get_rkm(),
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
    if ($r->header("Location") =~ m{/$date$}) {
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
                rkm => get_rkm(),

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
    if ($r->header("Location") =~ m{/$year$month$day$}) {
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
                rkm => get_rkm(),

                # Important:
                # This entry must already exist.
                body => $body,
                date => $self->cat_date({
                    year => $year,
                    month => $month,
                    day => $day,
                    cat_with => '',
                }),
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

    my ($sec, $min, $hour, $day, $mon, $year) = localtime;
    $year += 1900;
    $mon++;

    sprintf
        '%04d'.'%02d'.'%02d'.'%02d'.'%02d'.'%02d',
        $year, $mon, $day, $hour, $min, $sec;
}

# Read title and body.
sub read_title_body {
    my ($self, $file) = @_;

    # Execute filter command, if any.
    my $input = $file;
    if (length $self->filter_command) {
        $input = sprintf($self->filter_command." |", $file);
    }
    $self->debug("input: $input");
    my $FILE;
    if (not open($FILE, $input)) {
        $self->error("$input: $!");
    }
    my $title = <$FILE>; # first line.
    chomp($title);
    my $body = join('', <$FILE>); # rest of all.
    close($FILE);

    # Convert encodings.
    my $is_specified = length $self->client_encoding && length $self->server_encoding;
    my $is_same_encoding = $self->client_encoding eq $self->server_encoding;
    if ($self->enable_encode && $is_specified && ! $is_same_encoding) {
        $self->debug(sprintf 'Convert from %s to %s.',
                $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->client_encoding, $self->server_encoding);
        Encode::from_to($body, $self->client_encoding, $self->server_encoding);
    }

    return($title, $body);
}

# Find image file.
sub find_image_file {
    my ($self, $entry_filename) = @_;
    my ($base, $path, $type) = fileparse($entry_filename, qr/\.txt/);

    for my $ext ('jpg', 'png', 'gif') {
        my $imgfile = "$path$base.$ext";
        if (-f $imgfile) {
            $self->debug("found imgfile '$imgfile'.");

            if (-e($self->touch_file) and (-M($imgfile) > -M($self->touch_file))) {
                $self->debug("skip $imgfile (not updated).");
                next;
            }
            else {
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

    puts("Load $year-$month-$day.");

    my $date = $self->cat_date({
        year => $year,
        month => $month,
        day => $day,
        cat_with => '',
    });
    $self->debug(
        sprintf '%s/%s/edit?date=%s',
                $self->hatena_url, $self->username, $date);

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $res = $self->user_agent->simple_request(
        HTTP::Request::Common::GET(
            sprintf '%s/%s/edit?date=%s',
                    $self->hatena_url, $self->username, $date));

    $self->debug($res->status_line);

    if (not $res->is_success()) {
        $self->error("Load: Unexpected response: ", $res->status_line);
    }

    # Check entry exist.
    $res->content =~ /<form .*?action="\.\/edit" .*?>(.*<\/textarea>)/s;
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
    my $is_specified = length $self->client_encoding && length $self->server_encoding;
    my $is_same_encoding = $self->client_encoding eq $self->server_encoding;
    if ($self->enable_encode && $is_specified && ! $is_same_encoding) {
        $self->debug(sprintf 'Convert from %s to %s.', $self->client_encoding, $self->server_encoding);
        Encode::from_to($title, $self->server_encoding, $self->client_encoding);
        Encode::from_to($body, $self->server_encoding, $self->client_encoding);
    }

    puts("Load OK.");

    return ($title, $body);
}

# return entry's path,
# even if specified entry does not exist.
sub get_entrypath {
    my $self = shift;
    my ($year, $month, $day) = @_;

    my $filename = $self->build_entrypath(@_);
    return $filename if -f $filename;

    # find entry in all entries...
    for my $path ($self->get_entries) {
        # ignore headline.
        # if year, month, day are the same. return it.
        my $info = $self->get_entrydate($path);
        return $path
            if $info->{year} == $year
            && $info->{month} == $month
            && $info->{day} == $day;
    }

    # not found entry's path.
    return $filename
}

sub build_entrypath {
    my $self = shift;
    File::Spec->catfile(
        $self->txt_dir, $self->cat_date(@_) . '.txt'
    );
}

sub save_diary_entry {
    my $self = shift;
    my ($year, $month, $day, $title, $body);
    my $filename;

    if (ref $_[0] eq 'HASH') {
        # New way of passing arguments.
        # this can take 'headlines' option additionally.
        my %opt = %{ shift() };
        ($year, $month, $day, $title, $body) = @opt{qw(year month day title body)};
        $filename = $self->get_entrypath(
            $year, $month, $day,
            exists $opt{headlines} ? $opt{headlines} : undef
        );
    }
    else {
        # Original way of passing arguments.
        ($year, $month, $day, $title, $body) = @_;
        $filename = $self->get_entrypath($year, $month, $day);
    }

    my $OUT = FileHandle->new($filename, 'w')
                or $self->error("$!:$filename");
    $OUT->print($title."\n");
    $OUT->print($body);
    $OUT->close;

    puts("wrote $filename");

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

    if (! defined $user || length $user == 0) {
        $self->error("username is empty.");
    }
    if (! defined $pass || length $pass == 0) {
        $self->error("password is empty.");
    }

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

    if ($self->is_debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        STDERR->print("warning: $subname()  at $filename line $line:", @_, "\n");
    }
    else {
        STDERR->print("warning: ", @_, "\n");
    }
}

sub error {
    my $self = shift;
    my @errmsg;

    if ($self->is_debug) {
        my ($filename, $line, $subname) = (caller 1)[1, 2, 3];
        $filename = File::Basename::basename($filename);
        @errmsg = ("error: $subname() at $filename line $line:", @_, "\n");
    }
    else {
        @errmsg = ("error: ", @_, "\n");
    }

    if ($self->delete_cookie_if_error && -f $self->cookie_file) {
        unlink $self->cookie_file
            or $self->warning($self->warning.": $!");
    }

    die @errmsg;
}

sub debug {
    my $self = shift;

    return
        if ! $self->{debug_fh}->isa('IO::String')
        && ! $self->is_debug;

    $self->{debug_fh}->print("debug: ", @_, "\n");
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


# FIXME UTF8以外の環境だとMalformed UTF-8 characterと出る
#
# NOTE:
# pass "complete command line string".
# DON'T pass incomplete string. e.g.: "right double quote missing
sub shell_eval_str {
    my ($self, $line) = @_;
    my @args;

    return () unless defined $line;


    if ($line =~ /\n/m) {
        croak "give me the string line which does NOT contain newline!";
    }

    my $push_new_args = sub {
        $self->debug(sprintf "push new args!:[%s]", join ', ', @_);
        push @args, [@_];
    };
    my $push_args = sub {
        croak "push_args: receive empty args" unless @_;

        if (@args) {
            $self->debug(sprintf "push args!:[%s]", join ', ', @_);
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
        } else {
            $self->error("failed to parse cmdline string: ".$@);
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
        croak "give me options 'begin' and 'end' at least!";
    }

    my ($lquote, $rquote) = @opt{qw(begin end)};
    unless ($line =~ s/^$lquote//) {
        croak "regex '^$lquote' does not matched to ".dumper($line);
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


sub is_date {
    my ($self, $date) = @_;

    eval {
        $self->split_date($date);
    };
    $@ ? 0 : 1;
}

# split 'date'.
#
# NOTE:
# $self->get_entrydate() takes path,
# and returns undef or hash reference.
sub split_date {
    my ($self, $date) = @_;

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

    my ($year, $month, $day, $headlines);
    my %opt;
    if (ref $_[0] eq 'HASH') {
        # for receiving options.
        %opt = %{ shift() };
        ($year, $month, $day) = @opt{qw(year month day)};
        $headlines = $opt{headlines} if exists $opt{headlines};
    }
    else {
        ($year, $month, $day, $headlines) = @_;
    }
    %opt = (
        # default value
        cat_with => '-',

        %opt
    );

    # concat ymd.
    my $datename = sprintf '%04d%s%02d%s%02d',
                           $year, $opt{cat_with}, $month, $opt{cat_with}, $day;
    # concat headlines
    if ($headlines && @$headlines) {
        $datename .= '-'.join($opt{cat_with}, @$headlines);
    }

    return $datename;
}



sub is_command {
    my ($self, $cmd) = @_;
    exists $HWW_COMMAND{$cmd}
}

sub is_alias {
    my ($self, $cmd) = @_;
    exists $self->{config}{alias}{$cmd}
}

sub exist_alias {
    my ($self, $cmd) = @_;

    $self->is_alias($cmd)
        and
    exists $HWW_COMMAND{
        List::Utils::first {
            $self->expand_alias($self->{config}{alias}{$cmd})
        }
    };
}


sub regist_alias {
    my ($self, $from, $to) = @_;
    $self->{config}{alias}{$from} = $to;
}

# if $cmd is alias, expand it to some args.
sub expand_alias {
    my ($self, $cmd) = @_;

    if (exists $self->{config}{alias}{$cmd}) {
        my ($e) = $self->shell_eval_str($self->{config}{alias}{$cmd});
        return defined $e ? @$e : ();
    }
    else {
        return ($cmd);
    }
}




1;
