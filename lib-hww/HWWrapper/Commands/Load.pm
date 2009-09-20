package HWWrapper::Commands::Load;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{load} = {
        coderef => \&run,
        desc => 'load entries from hatena diary',
        option => {
            'a|all' => {
                desc => "fetch all entries",
            },
            'd|draft' => {
                desc => "fetch all draft entries",
            },
            'm|missing-only' => {
                desc => "fetch only missing entries",
            },
            # TODO fetch only different data's entries.
            # 'c|compare' => {
            # },
        },
    };
}


# TODO
# - 引数がない時は今日のエントリを持ってくる
# FIXME
# - 取ってきたファイルの先頭行に空行が入る
#   - --allコマンドの時かそうでない時かどっちだったか忘れた
sub run {
    my ($self, $args, $opt) = @_;

    my $all = $opt->{'a|all'};
    my $draft = $opt->{'d|draft'};


    if ($all) {    # --all
        $self->require_modules(qw(XML::TreePP));
        run_all($self, $args, $opt);
    }
    elsif ($draft) {    # --draft
        $self->require_modules(qw(XML::TreePP));
        run_draft($self, $args, $opt);
    }
    elsif (defined(my $ymd = shift @$args)) {
        my ($year, $month, $day) = $self->split_date($ymd);

        $self->login();

        # fetch one entry.
        my ($title, $body) = $self->load_diary_entry($year, $month, $day);
        # save.
        $self->save_diary_entry($year, $month, $day, $title, $body);

        $self->logout();
    }
    else {
        # error.
        $self->arg_error;
    }
}


sub run_all {
    my ($self, $args, $opt) = @_;
    my $missing_only = $opt->{'m|missing-only'};

    if (@$args) {
        $self->txt_dir = shift(@$args);
    }
    unless (-d $self->txt_dir) {
        mkdir $self->txt_dir or error($self->txt_dir.": $!");
    }

    # Login if necessary.
    $self->login();

    $self->user_agent->cookie_jar($self->cookie_jar);

    my $export_url = sprintf '%s/%s/export', $self->hatena_url, $self->username;
    $self->debug("GET $export_url");
    my $r = $self->user_agent->simple_request(
        HTTP::Request::Common::GET($export_url)
    );

    unless ($r->is_success) {
        $self->error("couldn't get entries:".$r->status_line);
    }
    puts("got $export_url");

    # NOTE: (2009-08-02)
    # if there were no entries on hatena,
    # $r->content returns
    #
    # <?xml version="1.0" encoding="UTF-8"?>
    # <diary>
    # </diary>
    #
    # so $entries
    #
    # {'diary' => ''}

    my $xml_parser = XML::TreePP->new;
    my $entries = $xml_parser->parse($r->content);

    unless (exists $entries->{diary}) {
        $self->error("invalid xml data returned from ".$self->hatena_url)
    }
    # exists entries on hatena diary?
    if (! ref $entries->{diary} && $entries->{diary} eq '') {
        puts(sprintf 'no entries on hatena diary. (%s)', $self->hatena_url);
        return;
    }
    unless (ref $entries->{diary} eq 'HASH'
        && ref $entries->{diary}{day} eq 'ARRAY') {
        $self->error("invalid xml data returned from ".$self->hatena_url)
    }
    $self->debug(sprintf '%d entries received.', scalar @{ $entries->{diary}{day} });


    for my $entry (@{ $entries->{diary}{day} }) {
        my ($year, $month, $day);
        if ($entry->{'-date'} =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
            ($year, $month, $day) = ($1, $2, $3);
        }
        else {
            $self->error(
                $entry->{'-date'}." is invalid format. (format: YYYY-MM-DD)"
            );
        }


        next if $missing_only
                && -f $self->get_entrypath($year, $month, $day);

        $self->save_diary_entry(
            $year,
            $month,
            $day,
            $entry->{'-title'},
            $entry->{body}
        );
    }

    $self->logout();
}

sub run_draft {
    my ($self, $args, $opt) = @_;
    my $missing_only = $opt->{'m|missing-only'};

    my $draft_dir = shift(@$args);
    $self->arg_error unless defined $draft_dir;
    unless (-d $draft_dir) {
        mkdir $draft_dir or $self->error("can't mkdir $draft_dir:$!");
    }

    # apply patch dynamically.
    {
        my $save_diary_draft = sub ($$$) {
            my $self = shift;
            my ($epoch, $title, $body) = @_;
            my $filename = draft_filename($self, $epoch);
            return if $missing_only && -f $filename;

            my $OUT;
            if (not open $OUT, ">", $filename) {
                $self->error("$!:$filename");
            }
            print $OUT $title."\n";
            print $OUT $body;
            close $OUT;
            $self->debug("save_diary_draft: wrote $filename");
            return 1;
        };

        my $draft_filename = sub ($) {
            my $self = shift;
            my ($epoch) = @_;
            return File::Spec->catfile($draft_dir, "$epoch.txt");
        };

        no strict 'refs';
        no warnings 'redefine';
        *save_diary_draft = $save_diary_draft;
        *draft_filename = $draft_filename;
    }


    $self->login;

    # don't use cookie.
    # just add X-WSSE header.
    my $temp_cookie = $self->user_agent->cookie_jar;
    $self->user_agent->cookie_jar(undef);


    my $url = $self->hatena_url->host.':'.$self->hatena_url->port;
    $self->user_agent->credentials($url, '', $self->username, $self->password);

    # http://d.hatena.ne.jp/{user}/atom/draft
    my $draft_collection_url = sprintf '%s/%s/atom/draft', $self->hatena_url, $self->username;
    my $xml_parser = XML::TreePP->new;

    # save draft entry.
    puts("getting drafts...");
    for (my $page_num = 1; ; $page_num++) {
        my $url = $draft_collection_url.($page_num == 1 ? '' : "?page=$page_num");
        # $self->user_agent->simple_request() can't handle authentication response.
        $self->debug("GET $url");
        my $r = $self->user_agent->request(
            HTTP::Request::Common::GET($url, 'X-WSSE' => $self->get_wsse_header)
        );

        unless ($r->is_success) {
            $self->error("couldn't get drafts: ".$r->status_line);
        }
        puts("got $url");

        my $drafts = $xml_parser->parse($r->content);
        my $feed = $drafts->{feed};

        unless (exists $feed->{entry}) {
            # No more drafts found.
            last;
        }

        for my $entry (@{ $feed->{entry} }) {
            my $epoch = (split '/', $entry->{'link'}{'-href'})[-1];
            save_diary_draft($self, $epoch, $entry->{'title'}, $entry->{'content'}{'#text'});
        }
    }

    $self->user_agent->cookie_jar($temp_cookie);
    $self->logout();
}



1;
