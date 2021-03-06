package HWWrapper::Commands::GenHtml;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;

use List::MoreUtils qw(uniq);



sub regist_command {
    $HWW_COMMAND{'gen-html'} = {
        coderef => \&run,
        desc => 'generate htmls from entry files',
        option => {
            'i|update-index' => {
                desc => "exec 'update-index' command after 'gen-html'",
            },
            'I=s' => {
                desc => "exec 'update-index' command with specified template file after 'gen-html'",
            },
            'm|missing-only' => {
                desc => "generate html only missing entries",
            },
            # TODO
            # '--ignore-headline' => {
            #     desc => "ignore the headline part of filename",
            # },
        },
    };
}


sub run {
    my ($self, $args, $opt) = @_;

    my $make_index = $opt->{'i|update-index'};
    my $index_tmpl = $opt->{'I=s'};
    my $missing_only = $opt->{'m|missing-only'};

    # prereq modules.
    $self->require_modules(qw(Text::Hatena));

    # both are directories, or both are files.
    my ($in, $out) = @$args;
    if (! defined $in || ! defined $out) {
        $self->arg_error;
    }


    if (-d $in && (-d $out || ! -e $out)) {
        unless (-e $out) {
            mkdir $out;
        }

        # YYYY-MM-DD
        my %html;
        if (-d $out) {
            my @html = uniq($self->get_entries($out, '*.html'), $self->get_entries($out, '*.htm'));
            %html = map {
                my $date = $self->get_entrydate($_);
                $self->cat_date(@$date{qw(year month day)}) => 1;
            } @html;
        }

        my $exists_html = sub {
            my ($filename) = @_;
            my $date = $self->get_entrydate($filename);
            return exists $html{
                $self->cat_date(@$date{qw(year month day)})
            };
        };

        for my $infile ($self->get_entries($in)) {
            next if $missing_only && $exists_html->($infile);

            my $outfile = File::Spec->catfile($out, basename($infile));
            $outfile =~ s/\.txt$/.html/;

            # generate html.
            gen_html($self, $infile, $outfile);
        }

        # call update-index.
        if (defined $index_tmpl) {
            $self->dispatch('update-index' => [$out, $index_tmpl])
        }
        elsif ($make_index) {
            $self->dispatch('update-index' => [$out]);
        }

    }
    elsif (-f $in && (-f $out || ! -e $out)) {
        unless (defined $self->get_entrydate($in)) {
            $self->error("$in is not entry text.");
        }

        gen_html($self, $in, $out);

        if (defined $index_tmpl) {
            $self->dispatch('update-index' => [dirname($out), $index_tmpl])
        }
        if ($make_index) {
            $self->dispatch('update-index' => [dirname($out)]);
        }

    }
    else {
        # arguments error. show help.
        $self->arg_error;
    }
}

sub gen_html {
    my ($self, $in, $out) = @_;


    # read entry text.
    my $IN = FileHandle->new($in) or $self->error("$in: $!");
    my @text = <$IN>;
    $IN->close;

    # cut title.
    shift @text;
    # cut blank lines in order not to generate blank section.
    shift @text while ($text[0] =~ /^\s*$/);

    puts("$in -> $out");
    my $html = Text::Hatena->parse(join "\n", @text);

    # write result.
    my $OUT = FileHandle->new($out, 'w') or $self->error("$out: $!");
    $OUT->print($html) or $self->error("can't write to $html");
    $OUT->close;
}


1;
