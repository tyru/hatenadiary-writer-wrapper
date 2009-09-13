package HWWrapper::Commands::Shell;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;

use Term::ReadLine;




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

            puts("type 'q' to leave. or type '?' to see built-in command's list.");
        }

        # EOF (or q or quit) to leave shell.
        SHELL:
        while (defined(my $line = readline_shell($self))) {

            $self->debug("eval...[$line]");
            DISPATCH:
            for my $shell_args ($self->shell_eval_str($line)) {
                next unless @$shell_args;

                $self->debug(sprintf "process %s...", dumper($shell_args));
                my ($cmd, @cmd_args) = @$shell_args;
                ($cmd, @cmd_args) = ($self->expand_alias($cmd), @cmd_args);

                use sigtrap qw(die INT QUIT);

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
        init_shell_cmd($self);

        $term = Term::ReadLine->new;
        # define completion function!
        $term->Attribs->{completion_function} = gen_compl_func($self);

        # initialize all command's info.
        HWWrapper::Commands->regist_all_command() || do {
            $self->debug("regist_all_command() was failed.");
            $self->error("failed to initialize the shell");
        };

        $self->debug("initialized the shell...");
    }


    sub init_shell_cmd {
        my $self = shift;

        %shell_cmd = (
            quit => sub { goto EXIT_LOOP },
            q => sub { $shell_cmd{quit}->(@_) },    # same as 'quit'.
            '?' => sub {
                puts("shell built-in commands here:");
                puts("  $_") for keys %shell_cmd;
                puts();
                puts("if you want to see the helps of hww's commands, type 'help'.");
                STDOUT->flush;
            },
            h => sub { $shell_cmd{'?'}->() },    # same as '?'

            login => sub {
                my $force = 0;
                $self->get_opt([@_], {
                    'f|force' => \$force,
                });
                $self->login(force => $force);
            },
            logout => sub {
                my $force = 0;
                $self->get_opt([@_], {
                    'f|force' => \$force,
                });
                $self->logout(force => $force);
            },

            # make/delete/show aliases.
            alias => sub {
                if (@_) {
                    my ($name, $value) = @_;

                    if (defined $value) {
                        # alias it.
                        $self->{config}{alias}{$name} = $value;
                    } else {
                        # delete its alias.
                        delete $self->{config}{alias}{$name};
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

            # change group.
            group => sub {
                my ($group) = @_;

                my $apply_config = sub {
                    # copy it. don't change original refhash.
                    my %c = %{ shift() };

                    while (my ($k, $v) = each %c) {
                        $self->debug("  $k => $v");
                        $self->$k = $v;
                    }
                };

                if (defined $group) {
                    if (exists $self->{config}{group}{$group}) {    # change the group.
                        # restore previous config.
                        $self->debug("restore previous config...");
                        $apply_config->($self->{previous_group_stash});

                        # change the config to $group's config.
                        my $group_config = $self->{config}{group}{$group};
                        for my $k (keys %$group_config) {
                            # stash current config.
                            $self->{previous_group_stash}{$k} = $self->$k;
                        }
                        $self->debug("apply $group config...");
                        $apply_config->($group_config);

                        # change the current group.
                        $self->{current_group} = $group;
                    }
                    else {
                        $self->warning("$group: no such a group.");
                        return;
                    }

                    puts("change group to '$group'.");
                }
                else {
                    # restore previous config.
                    $self->debug("restore previous config...");
                    $apply_config->($self->{previous_group_stash});
                    $self->{previous_group_stash} = {};

                    $self->{current_group} = '';

                    puts("change group to main group.");
                }
            },
        );
    }


    sub readline_shell {
        my $self = shift;

        my $line = $term->readline($self->prompt_str);
        # EOF for the first time
        unless (defined $line) {
            # exit shell
            return undef;
        }
        elsif ($line =~ /^\s*$/) {
            # retry to read line.
            @_ = ($self);
            goto &readline_shell
        }

        # read lines until $line is complete
        until ($self->is_complete_str($line)) {
            if (length $line && substr($line, -1, 1) eq  "\\") {
                chop $line;
            }

            $self->debug("reading next line...[$line]");
            my $l = $term->readline($self->prompt_next_line_str);

            # EOF
            return $line unless defined $l;
            $line .= $l;
        }

        return $line;
    }


    sub gen_compl_func {
        my ($self) = @_;


        ### for debug ###
        my $dwarn = sub {
            return unless $self->is_debug;
            warn @_, "\n";
            sleep 1;
        };

        ### complete all commands ###
        my $comp_cmd = sub {
            keys(%HWW_COMMAND), keys(%shell_cmd)
        };

        ### split '|' in options ###
        my $get_options = sub {
            map {
                s/=.$//;
                /\|/ ? (split /\|/) : $_
            } keys %{ $_[0] };
        };

        ### find commands in $all_options ###
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

        ### directory's separator ###
        my %sep = (
            MSWin32 => qr{\\ | /}x,
            MacOS => ':',
        );
        my $sep = exists $sep{$^O} ? $sep{$^O} : '/';

        ### complete files ###
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
        my $comp_files = sub {
            my ($completed, $last_args) = @_;

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
        };

        ### complete config ###
        my $comp_config = sub {
            keys %{ $self->{config} };
        };



        ### define completion function ###
        return sub {
            my ($prev_word, $cur_text, $str_len) = @_;
            my $completed = $cur_text =~ / $/;
            my @match;

            unless ($self->is_complete_str($cur_text)) {
                $dwarn->("[$cur_text] is not complete string. skip...");
                return undef;
            }


            # separate $cur_text to array.
            my @args = $self->shell_eval_str($cur_text);
            if (@args == 0) {
                return $comp_cmd->();
            }

            # last argument splitted with ';'.
            my @last_args = @{ $args[-1] };
            if (@last_args == 0) {
                return $comp_cmd->();
            }
            $dwarn->(join '', map { "[$_]" } @last_args);


            ### complete word ###
            # aliases.
            if ($self->is_alias($last_args[0])) {
                $dwarn->("$last_args[0] is alias.");

                return $last_args[0]
                    if $prev_word eq $last_args[0] && ! $completed;
            }
            # commands.
            elsif ($self->is_command($last_args[0])) {
                $dwarn->("$last_args[0] is command.");

                return $last_args[0]
                    if $prev_word eq $last_args[0] && ! $completed;

                # 'help' command
                if ($last_args[0] eq 'help' && (@last_args == 1 || (@last_args == 2 && ! $completed))) {
                    # if arg 1 'help' is not completed, return it.
                    return $last_args[0]
                        if $prev_word eq 'help' && ! $completed;
                    # or return all commands.
                    return $comp_cmd->();
                }

                # complete options
                my $options = $HWW_COMMAND{ $last_args[0] }{option};
                if (@last_args >= 2 && $last_args[-1] =~ /^(--?)(.*)$/) {
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
            }
            # shell built-in commands.
            elsif (exists $shell_cmd{ $last_args[0] }) {
                $dwarn->("$last_args[0] is built-in command.");

                return $last_args[0]
                    if $prev_word eq $last_args[0] && ! $completed;

                if ($last_args[0] eq 'config' && (@last_args == 1 || (@last_args == 2 && ! $completed))) {
                    # if arg 1 'config' is not completed, return it.
                    return $last_args[0]
                        if $prev_word eq 'config' && ! $completed;
                    # or return all config.
                    return $comp_config->();
                }

            }

            ### incompleted word ###
            # aliases.
            elsif (@match = $grep_cmd->($last_args[0], {%{ $self->{config}{alias} }})) {
                return @match;
            }
            # commands.
            elsif (@match = $grep_cmd->($last_args[0], {%HWW_COMMAND})) {
                return @match;
            }
            # shell built-in commands.
            elsif (@match = $grep_cmd->($last_args[0], {%shell_cmd})) {
                return @match;
            }

            $dwarn->("reach to the end of func");
            return $comp_files->($completed, [@last_args]);
        }
    }
}


1;
