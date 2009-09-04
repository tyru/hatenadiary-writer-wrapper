package HWWrapper::Commands::GenHtml;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands qw(%HWW_COMMAND);
# export sub who does not take $self.
use HWWrapper::Functions;




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


# XXX
# - 恐らく見出しの有無に関わらず、ファイルを作ってしまう(-mオプションが効かない)
#   - get_entrypath()してから、存在してるか調べる
#   - gen-htmlに関わらず--missing-onlyオプションがあるコマンドはチェック
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

        for my $infile ($self->get_entries($in)) {
            my $outfile = File::Spec->catfile($out, basename($infile));
            # *.txt -> *.html
            $outfile =~ s/\.txt$/.html/;

            # '--missing-only' option generate only non-existent file.
            next if $missing_only && -f $outfile;

            # generate html.
            gen_html($self, $infile, $outfile);
        }

        # call update-index.
        if (defined $index_tmpl) {
            $self->dispatch('update-index' => [$index_tmpl, $out])
        }
        elsif ($make_index) {
            $self->dispatch('update-index' => [$out]);
        }

    }
    elsif (-f $in && (-f $out || ! -e $out)) {
        gen_html($self, $in, $out);

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

    unless (defined $self->get_entrydate($in)) {
        return;
    }


    my $IN = FileHandle->new($in, 'r') or $self->error("$in:$!");

    my @text = <$IN>;
    # cut title.
    shift @text;
    # cut blank lines in order not to generate blank section.
    shift @text while ($text[0] =~ /^\s*$/);

    my $html = Text::Hatena->parse(join "\n", @text);
    $IN->close;

    puts("gen_html: $in -> $out");

    my $OUT = FileHandle->new($out, 'w') or $self->error("$out:$!");
    $OUT->print($html) or $self->error("can't write to $html");
    $OUT->close;
}


1;
