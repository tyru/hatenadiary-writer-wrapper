package HWWrapper::Commands::UpdateIndex;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{'update-index'} = {
        coderef => \&run,
        desc => 'make html from template file by HTML::Template',
        option => {
            'm|max-length=s' => {
                desc => "max summary byte length",
            },
        },
    };
}


# TODO
# - index.htmlだけでなく、いくつかのページを持ったindex.htmlを出力。
#   (index<連番>.htmlという形にするか、2ページ目以降はどこかのディレクトリに納めるかは、どうやって決める？)
# - 1ページ当たりのエントリ数(オプション)
# - max-lengthをバイト数じゃなく文字数にする
sub run {
    my ($self, $args, $opt) = @_;

    $self->require_modules(qw(
        HTML::TreeBuilder
        HTML::Template
        Time::Local
    ));

    my ($html_dir, $index_tmpl) = @$args;
    unless (defined $html_dir) {
        $self->arg_error;
    }
    unless (defined $index_tmpl) {
        $index_tmpl = File::Spec->catfile($html_dir, 'index.tmpl');
    }

    unless (-f $index_tmpl) {
        $self->error("$index_tmpl: $!");
    }
    update_index($self, $opt, $html_dir, $index_tmpl);
}


sub update_index {
    my ($self, $opt, $html_dir, $index_tmpl) = @_;

    my $max_strlen;
    if (defined $opt->{'m|max-length=s'}) {
        $max_strlen = $opt->{'m|max-length=s'};
    }
    else {
        $max_strlen = 200;
    }


    my $template = HTML::Template->new(
        filename => $index_tmpl,
        die_on_bad_params => 0,    # No die if set non-existent parameter.
    );

    my @entry;
    for my $path ($self->get_entries($html_dir, '*.html')) {
        my $basename = basename($path);
        next    unless $basename =~ /^(\d{4})-(\d{2})-(\d{2})(?:-.+)?\.html$/;


        my ($year, $month, $day);
        my @date = ($year, $month, $day) = ($1, $2, $3);
        my $epoch = Time::Local::timelocal(0, 0, 0, $day, $month - 1, $year - 1900);


        my $tree = HTML::TreeBuilder->new_from_file($path);

        my $title = do {
            my ($h3) = $tree->find('h3');

            my $title;
            if (defined $h3) {
                $title = $h3->as_text;
                $title =~ s/^\*?\d+\*//;
            }
            else {
                $title = "no title";
            };

            $title;
        };

        my $summary = do {
            # Get the inner text of all tags.
            my $as_text;
            $as_text = sub {
                my ($elements, $text) = @_;
                $text = "" unless defined $text;

                while (defined(my $elem = shift @$elements)) {
                    if (blessed($elem) && $elem->isa('HTML::Element')) {
                        next    if lc($elem->tag) eq 'h3';    # Skip headline
                        @_ = ([$elem->content_list, @$elements], $text);
                        goto &$as_text;
                    }
                    else {
                        my $s = "$elem";    # Stringify (call overload "")
                        next    if $s =~ /\A\s*\Z/m;
                        $s =~ s/\s*/ /m;    # Shrink all whitespaces
                        $text .= $s;
                    }

                    return $text.' ...' if length($text) > $max_strlen;
                }

                return $text;
            };

            my $sm;
            for my $section ($tree->look_down(class => 'section')) {
                $sm .= $as_text->([$section->content_list]);
                last    if length($sm) >= $max_strlen;
            }

            $sm;
        };

        $tree = $tree->delete;    # For memory


        # Newer to older
        unshift @entry, {
            'date'    => join('-', @date),
            'year'    => $date[0],
            'month'   => $date[1],
            'day'     => $date[2],
            'epoch'   => $epoch,
            'title'   => $title,
            'link'    => $basename,
            'summary' => $summary,
        };
    }
    $template->param(entrylist => \@entry);

    my $epoch = time;
    my ($year, $month, $day, $hour, $min, $sec)
        = (localtime $epoch)[5, 4, 3, 2, 1, 0];
    $year += 1900;
    $month++;
    my $iso8601 = $self->cat_date($year, $month, $day)
                    .'T'
                    .sprintf('%02d:%02d:%02d', $hour, $min, $sec)
                    .'Z';

    $template->param(lastchanged_datetime => $iso8601);
    $template->param(lastchanged_year  => $year);
    $template->param(lastchanged_month => $month);
    $template->param(lastchanged_day   => $day);
    $template->param(lastchanged_epoch => $epoch);


    # Output
    my $index_html = File::Spec->catfile($html_dir, "index.html");
    open my $OUT, '>', $index_html or $self->error("$index_html:$!");
    print $OUT $template->output;
    close $OUT;
    puts("wrote $index_html");

    $self->debug("generated $index_html...");
}


1;
