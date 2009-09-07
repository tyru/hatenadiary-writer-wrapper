package HWWrapper::Commands::Copyright;

use strict;
use warnings;
use utf8;

# export some variables and subs.
use HWWrapper::Commands::Base;




sub regist_command {
    $HWW_COMMAND{copyright} = {
        coderef => \&run,
        desc => 'copyright',
    };
}


sub run {
    # hw.pl
    print <<EOD;

hw.pl - Hatena Diary Writer (with Loader).

Copyright (C) 2004,2005,2007 by Hiroshi Yuki.
<hyuki\@hyuki.com>
http://www.hyuki.com/techinfo/hatena_diary_writer.html

Special thanks to:
- Ryosuke Nanba http://d.hatena.ne.jp/rna/
- Hahahaha http://www20.big.or.jp/~rin_ne/
- Ishinao http://ishinao.net/

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

'Hatena Diary Loader' originally written by Hahahaha(id:rin_ne)
   http://d.hatena.ne.jp/rin_ne/20040825#p7

Modified by Kengo Koseki (id:koseki2)
   http://d.hatena.ne.jp/koseki2/
EOD
    # hww.pl
    print <<EOD;


hww.pl - Hatena Diary Writer Wrapper

Copyright (C) 2009 by tyru.
<tyru.exe\@gmail.com>

EOD
}


1;
