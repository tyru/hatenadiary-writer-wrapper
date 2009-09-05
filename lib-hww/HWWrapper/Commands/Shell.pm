package HWWrapper::Commands::Shell;

use strict;
use warnings;
use utf8;

use base qw(HWWrapper::Commands::Base);

# export our variables.
use HWWrapper::Commands qw(%HWW_COMMAND);
# export sub who does not take $self.
use HWWrapper::Functions;




sub regist_command {
    $HWW_COMMAND{shell} = {
        coderef => \&run,
        desc => 'run commands like a shell',
    };
}


{
    my %shell_cmd;
    my $term;
    my $initialized;


    sub run {
        my ($self, $args) = @_;

        unless ($initialized) {
            init_shell($self);
            $initialized = 1;
        }


        local $HWWrapper::Hook::BuiltinFunc::exit = sub (;$) {
            $self->error("program exited with ".(@_ ? $_[0] : 0));
            # trapped with eval, this won't die.
        };

        my $readline; $readline = sub {
            my $line = $term->readline("> ");
            # EOF for the first time
            unless (defined $line) {
                # exit shell
                return undef;
            }
            elsif ($line =~ /^\s*$/) {
                # retry to read line.
                goto &$readline;
            }

            # read lines until $line is complete
            until ($self->is_complete_str($line)) {
                if (length $line && substr($line, -1, 1) eq  "\\") {
                    chop $line;
                }

                $self->debug("reading next line...[$line]");
                my $l = $term->readline("");

                # EOF
                return $line unless defined $l;
                $line .= $l;
            }

            return $line;
        };


        # EOF (or q or quit) to leave shell.
        SHELL:
        while (defined(my $line = $readline->())) {

            $self->debug("eval...[$line]");
            DISPATCH:
            for my $shell_args ($self->shell_eval_str($line)) {
                next unless @$shell_args;

                $self->debug(sprintf "process %s...", dumper($shell_args));
                my ($cmd, @cmd_args) = @$shell_args;
                ($cmd, @cmd_args) = ($self->expand_alias($cmd), @cmd_args);


                if ($cmd eq 'shell') {
                    $self->warning("you have been already in the shell.");
                    last DISPATCH;
                }
                elsif (exists $shell_cmd{$cmd}) {
                    eval {
                        $shell_cmd{$cmd}->(@cmd_args);
                    };
                }
                elsif ($self->is_command($cmd)) {
                    eval {
                        $self->dispatch($cmd => \@cmd_args);
                    };
                }
                else {
                    # I can emulate 'correct' in zsh by using familiar_words().
                    # but that might be annoying if that's default.
                    my @familiar = $self->familiar_words(
                        $cmd,
                        [
                            keys(%HWW_COMMAND),
                            keys(%shell_cmd),
                            keys(%{ $self->{config}{alias} })
                        ],
                        {
                            diff_strlen => 4,
                            partial_match_len => 3,
                        },
                    );

                    if (@familiar) {
                        # so currently I just suggest that words.
                        puts("\nDid you mean this?");
                        puts("\t$_") for @familiar;
                    }
                    else {
                        $self->warning("$cmd: command not found");
                    }
                }

                $self->warning($@) if $@;
            }
        }

        EXIT_LOOP:
    }


    sub init_shell {
        my $self = shift;


        # define built-in commands.
        %shell_cmd = (
            quit => sub { goto EXIT_LOOP },
            q => sub { $shell_cmd{quit}->(@_) },    # same as 'quit'.
            '?' => sub {
                puts("shell built-in commands here:");
                puts("  $_") for keys %shell_cmd;
                puts();
                puts("if you want to see the help of hww's commands, type 'help'.");
                STDOUT->flush;
            },
            h => sub { $shell_cmd{'?'}->() },    # same as '?'

            login => sub { $self->login },
            logout => sub { $self->logout },

            # make/delete/show aliases.
            alias => sub {
                if (@_) {
                    my ($name, $value) = @_;

                    if (defined $value) {
                        # delete its alias.
                        delete $self->{config}{alias}{$name};
                    } else {
                        # alias it.
                        $self->{config}{alias}{$name} = $value;
                    }
                }
                else {
                    # show all aliases.
                    for my $k (sort keys %{ $self->{config}{alias} }) {
                        puts(sprintf '"%s" = "%s"', $k, $self->{config}{alias}{$k});
                    }
                }
            },

            # modify $self->{config} value.
            config => sub {
                if (@_) {
                    my ($name, $value) = @_;

                    unless (exists $self->{config}{$name}) {
                        $self->warning("'$name' is not config name.");
                        return;
                    }

                    if (defined $value) {
                        if (ref $self->$name) {
                            $self->warning("cannot modify '$name' value.");
                        }
                        else {
                            # set.
                            $self->$name = $value;
                        }
                    }
                    else {
                        puts(sprintf '"%s" = %s',
                            $name, dumper($self->$name));
                    }
                }
                else {
                    for my $name (sort keys %{ $self->{config} }) {
                        next if ref $self->$name;
                        puts(sprintf '"%s" = %s',
                            $name, dumper($self->$name));
                    }
                }
            },
        );


        $term = Term::ReadLine->new;

        # define completion function!
        $term->Attribs->{completion_function} = gen_compl_func($self);

        # initialize all command's info.
        $self->regist_all_command();


        $self->debug("initialized the shell...");
    }


    sub gen_compl_func {
        my ($self) = @_;


        # for debug.
        my $dwarn = sub {
            return unless $self->is_debug;
            warn @_, "\n";
            sleep 1;
        };

        # complete all commands.
        my $comp_cmd = sub { keys %HWW_COMMAND };

        # split '|' in options.
        my $get_options = sub {
            map {
                /\|/ ? (split /\|/) : $_
            } keys %{ $_[0] };
        };

        # find commands in $all_options.
        # e.g.:
        # $incomp_cmd: di
        # $all_options: { diff => { ... }, help => { ...}, ... }
        my $grep_cmd = sub {
            my ($incomp_cmd, $all_options) = @_;
            grep {
                if ($self->is_debug) {
                    STDERR->print(
                        "match [$_]? ", ($incomp_cmd eq substr($_, 0, length $incomp_cmd)), "\n"
                    )
                }
                $incomp_cmd eq substr($_, 0, length $incomp_cmd)
            } $get_options->($all_options);
        };

        my $glob_files = sub {
            my %opt = @_;
            $opt{file} = '*' unless exists $opt{file};

            if (exists $opt{dir} && -d $opt{dir}) {
                $dwarn->("complete $opt{file} in '$opt{dir}'");
                glob $opt{dir}.'/'.$opt{file};
            }
            else {
                $dwarn->("complete $opt{file} in current dir");
                glob $opt{file};
            }
        };

        # directory's separator.
        my %sep = (
            MSWin32 => qr{\\ | /}x,
            MacOS => ':',
        );
        my $sep = exists $sep{$^O} ? $sep{$^O} : '/';



        ### define completion function ###
        return sub {
            my ($prev_word, $cur_text, $str_len) = @_;
            my $completed = $cur_text =~ / $/;

            unless ($self->is_complete_str($cur_text)) {
                $dwarn->("[$cur_text] is not complete string. skip...");
                return undef;
            }


            my @args = $self->shell_eval_str($cur_text);
            if (@args == 0) {
                return $comp_cmd->();
            }

            my $last_args = $args[-1];
            if (@$last_args == 0) {
                return $comp_cmd->();
            }
            $dwarn->(join '', map { "[$_]" } @$last_args);


            if ($last_args->[0] eq 'help') {
                # stop completion
                # unless num of args is 1, or num of args is 2 and not completed
                return $glob_files->()
                    unless @$last_args == 1 || (@$last_args == 2 && ! $completed);
                # if arg 1 'help' is not completed, return it
                return $last_args->[0]
                    if $prev_word eq 'help' && ! $completed;
                # or return all commands
                return $comp_cmd->();
            }
            # complete command
            elsif ($self->is_command($last_args->[0])) {
                return $last_args->[0]
                    if $prev_word eq $last_args->[0] && ! $completed;

                # complete options
                my $options = $HWW_COMMAND{ $last_args->[0] }{option};
                if (@$last_args >= 2 && $last_args->[-1] =~ /^(--?)(.*)$/) {
                    my ($bar, $opt) = ($1, $2);
                    $dwarn->("matced!:[$opt]");

                    if (length $opt) {
                        $dwarn->("grep options");
                        return map { $bar.$_ } $grep_cmd->($opt, $options);
                    }
                    else {
                        $dwarn->("all options");
                        return map { $bar.$_ } $get_options->($options);
                    }
                }

                if ($completed) {
                    return $glob_files->();
                }
                elsif ($last_args->[-1] =~ m{^ (.*) $sep $}x) {    # ending with $sep
                    # complete directory's files
                    return $glob_files->(dir => $1);
                } else {
                    # complete incomplete files
                    return $glob_files->(file => $last_args->[-1].'*');
                }
            }
            # incomplete command
            elsif (my @match = $grep_cmd->($last_args->[0], \%HWW_COMMAND)) {
                return @match;
            }


            return $glob_files->();
        }
    }
}


1;
