
概要
============================================

結城浩さんが作った[はてなダイアリーライター（略称：はてダラ）](http://www.hyuki.com/techinfo/hatena_diary_writer.html)にさまざまな機能を加えたものです。
個人的に

- はてなダイアリーライターラッパー (そのまま)
- はてだらっぱー
- hww (スクリプト名hww.plから)

とか呼んでいます。
このドキュメントでは短いので*hww*で統一します。




日記を書き始める
============================================

依存モジュールのインストール
--------------------------------------------

    $ cpan Bundle::HWWrapper

いくつかのモジュールは必要になった時に呼ばれるので、無くても構いません。
ただhww.plを起動して次のようなメッセージが出なければ、必須のモジュールがインストールされていない可能性があります。

    Usage:
            $ perl hww.pl [HWW_OPTIONS] [HW_OPTIONS] COMMAND [ARGS]

    available commands:
      apply-headline
      copyright
      diff
      editor
      gen-html
      help
      init
      load
      release
      revert-headline
      shell
      status
      touch
      truncate
      update-index
      verify
      version

    and if you want to know hww.pl's option, perldoc -F hww.pl


設定ファイルを書く
--------------------------------------------

まずinitコマンドを実行します。
するとconfig-hww.txt.sampleというサンプルの設定ファイルが
config-hww.txtにコピーされるので、それをサンプルを元に編集していってください。
config-hww.txtを自分で作成しても構いません。

またconfig.txtというはてダラの設定ファイルがあればそれを読み込みます。
はてダラを使っていた人は設定ファイルや日記ファイルをコピーしてくればすぐ使えるはずです。

設定ファイルについて詳しく知りたい方は「設定」の項を参照してください。

これでやるべき事は終了です。
あとは日記を書くだけです。




どんなことができるのか
============================================

*hww*は、具体的には次のようなコマンドを持っています。(2009-09-07 現在)
詳しくはヘルプを見てください。(日本語ヘルプ作成中)


- apply-headline
    - 日記ファイルからタグを探しだして、タグをファイル名に付けたフォーマットに変える。直すにはrevert-headlineを使う。
- copyright
    - Copyrightを表示します。
- diff
    - はてなダイアリーとの差分を表示します
- editor
    - 好きなエディタで特定の日付を開く。日付が引数で指定されなければ今日の日付が開かれる。エディタはconfig-hww.txtで設定可能。デフォルトは$EDITOR(もしあれば)。
- gen-html
    - 日記ファイルからHTMLを作成します。要Text::Hatena。
- help
    - ヘルプを表示します。引数にコマンド名を与えればそれのコマンドを表示。現在日本語ヘルプ作成中です。
- init
    - config-hww.txt.sampleをconfig-hww.txtにコピーし、クッキーを削除します。
- load
    - はてなダイアリーから特定の、あるいは全ての日記ファイルを持ってきます。
- release
    - 日記をアップロードします。
- revert-headline
    - apply-headlineでを元に戻します。
- shell
    - 全てのコマンドを起動できます。また補完も効きます。cygwinのようなスクリプトの起動に時間がかかる環境でも有効かもしれません。
- status
    - 更新された日記ファイルを表示します。表示されたファイルがreleaseコマンドあるいはupdateコマンドでアップロードされます。
- touch
    - touch.txtを更新します。これをすることでstatusにファイルが表示されなくなり、日記のアップロードもされなくなります。またアップロードしたい場合は、その日記ファイルを更新するか、releaseコマンドの引数に指定してください。これははてダラの-fオプションにあたります。
- truncate
    - 日記ファイルの前後の空白を取り除きます。
- update
    - release -tオプションと同じです。
- update-index
    - gen-htmlで作成したHTMLのディレクトリとテンプレートファイルからindex.htmlを作成します。
- verify
    - 現在の状態が間違っていないか確認します。現在は日記の重複を探しだすだけです。
- version
    - バージョンを表示


いくつかのコマンドには追加モジュールが必要です。
Bundle/HWWrapper.pmにまとめてあるので、コマンドラインから

    $ cpan Bundle::HWWrapper

とすればインストールできるはずです。




特徴 (おすすめの機能など)
============================================

git風のコマンド
--------------------------------------------

gitのようにコマンドを持つことでそれぞれの操作を覚えにくいオプションに頼ることなく明確に行うことができます。


shellコマンド
--------------------------------------------

shellコマンドは
- コマンドのオプションや引数の補完機能
- 「;」で順次実行
- 行末に「\\」があると次の行に続けて読みにいく
などのシェルとしての基本的な機能を備えています。

またshellコマンドの中でのみ実行できるビルトイン関数なども存在します。
詳しくはシェルで「?」と打ってみてください。

現在は「&amp;」によるバックグラウンド実行などを実装したいと考えています。


プラグイン？
--------------------------------------------

※まだ未実装です


グループ機能
--------------------------------------------

複数のダイアリーを管理できます。
一つのアカウントで複数のダイアリーを持つ人向けです。
使用方法は最後の「config-hww.txt サンプル」を参照してください。




はてダラと違う動作
============================================

オプション
--------------------------------------------

いくつかのオプションを持ちません。

- -fオプション
- -tオプション

削除した理由は「コマンドの」オプション引数で変更することが可能になったからです。
これ以外のオプションは全て指定可能です。


ログインをやり直す
--------------------------------------------

ログインを失敗した場合何回かやり直しをします。
この回数はlogin\_retry\_numで設定可能です。




設定
============================================

設定が読み込まれる順番は

1. 設定ファイル
2. 引数

です。
まず設定ファイルが読まれ、次に引数で指定された値を読みます。
つまり引数で指定された方が後に読み込まれるので優先順位が高いです。

設定ファイルには2つあり、はてダラの設定ファイル(config.txt)とhww.plの設定ファイル(config-hww.txt)があります。
読み込まれる順番は

1. config.txt
2. config-hww.txt

です。
(設定のファイル名はそれぞれオプションや設定ファイルで変えることが可能です。)

設定ファイルで指定できる全ての設定の名前は以下の通りです。(2009-09-07 現在)
また設定の値はshellコマンド実行中にconfigビルトイン関数で変更や表示をすることが可能です。


- config\_file
    - デフォルトは"config.txt"
    - -n, --config-hwオプションで指定可能
    - はてダラの設定ファイルです。
- delete\_cookie\_if\_error
    - デフォルトは0
    - 1だとエラー時にクッキーを削除し、0だと削除しません。1に設定すると認証に関係がない操作でエラーになってもクッキーが削除されるようになります。
- delete\_title
    - デフォルトは"delete"
    - 日記の先頭にタイトルの代わりにこの文字列を書くことで、はてなダイアリーからその日付の日記を削除します。
- editor
    - デフォルトは$EDITOR(環境変数)
    - お好みのエディタへのパスかファイル名です。絶対パスでない場合は$PATHから探します。
- groupname
    - デフォルトは""
    - -g, --groupオプションで指定可能
- http\_proxy
    - デフォルトは""
    - プロキシへのURLを指定します。(例：http://www.example.com:8080/)
- is\_debug
    - デフォルトは0
    - -d, --debugオプションで指定可能
    - デバッグメッセージが表示されます。
- is\_debug\_stderr
    - デフォルトは0
    - -D, --debug-stderrオプションで指定可能
    - デバッグメッセージが標準エラー出力に表示されます。
- load\_from\_pit
    - デフォルトは0
    - Config::Pitを使い、~/.pitからユーザ名とパスワードを取得します。設定ファイルにユーザ名とパスワードを書かなくて住むようになります。
- pit\_domain
    - デフォルトは"hatena.ne.jp"
    - Config::Pitで取得するドメイン名です。
- login\_retry\_num
    - デフォルトは2
    - ログインを成功するまで繰り返す回数です。
- no\_timestamp
    - デフォルトは0
    - -M, --no-timestampオプションで指定可能
    - 1だと\*t\*という見出しを現在のタイムスタンプに置き換えません。
- username
    - デフォルトは""
    - -u, --usernameオプションで指定可能
    - はてなのユーザ名です
- password
    - デフォルトは""
    - -p, --passwordオプションで指定可能
    - はてなのパスワードです
- timeout
    - デフォルトは180
    - -T, --timeoutオプションで指定可能
    - 接続のタイムアウト時間の秒数です。
- touch\_file
    - デフォルトは"touch.txt"
    - このファイルより更新日が新しいファイルがアップロード候補です。次回releaseコマンドが実行された時にアップロードされます
- txt\_dir
    - デフォルトは"."
    - 日記ファイルを置くディレクトリです。
- use\_cookie
    - デフォルトは0
    - -c, --use-cookieオプションで指定可能
    - クッキーを使ってログインとログアウトを省略することが可能になります。
- agent
    - デフォルトは"HatenaDiaryWriter/{バージョン番号}"
    - -a, --agentオプションで指定可能
    - ユーザエージェントです。
- cookie\_file
    - デフォルトは"cookie.txt"
    - クッキーのファイル名です。
- filter\_command
    - デフォルトは""
    - 例えば"iconv -f euc-jp -t utf-8 %s"を指定するとエンコーディングをEUC-JPからUTF-8へと変換したりできます。詳しくは結城浩さんのHPの[設定ファイルの例(2)](http://www.hyuki.com/techinfo/hatena_diary_writer.html#config_example2)などを見てください。
- no\_load\_config\_hw
    - デフォルトは0
    - --no-load-hwオプションで指定可能
    - config.txtを読み込むのをスキップします。
- alias.\*
    - デフォルトは{update =&gt; "release -t"}
    - デフォルトの値は、updateを実行すると代わりに"release -t"が実行されるという意味です。元々updateはコマンドでしたが色々あってエイリアスになりました。設定例などはサンプルの設定ファイル(config-hww.txt.sample)を見てください。
- server\_encoding
    - デフォルトは''
    - はてなダイアリーサーバのエンコーディングです。はてなグループのダイアリーを書く場合にはutf-8にすると文字化けせずに済みます。はてなダイアリーの場合はeuc-jpにしてください。server\_encodingかclient\_encodingどちらかが空文字だと文字エンコーディングの変換がされません。
- client\_encoding
    - デフォルトは''
    - 日記ファイルのエンコーディングです。server\_encodingかclient\_encodingどちらかが空文字だと文字エンコーディングの変換がされません。


変える必要がないと思われるもの
--------------------------------------------

- enable\_encode
    - デフォルトはEncodeモジュールがインストールされていれば1、されていなければ0
    - 1だとclient\_encodingとserver\_encodingが違っていた時に変換します。
- enable\_ssl
    - 常に1
    - はてダラの-Sオプションにあたるものです。
- no\_load\_config\_hww
    - デフォルトは0
    - --no-load-hwwオプションで指定可能
    - この設定を設定ファイル(config-hww.txt)で変えても意味がありません。--no-load-hwwオプションで指定することで設定ファイルを読み込まずにスキップします。
- config\_hww\_file
    - デフォルトは'config-hww.txt'
    - -N, --config-hwwオプションで指定可能
    - hww.plの設定ファイルです。この設定を設定ファイル(config-hww.txt)で変えても意味がありません。--config-hwwオプションで指定することで読み込む設定ファイル名を変えることができます。
- hatena\_sslregister\_url
    - デフォルトはCrypt::SSLeayがインストールされていれば'https://www.hatena.ne.jp/login'、されていなければ'http://www.hatena.ne.jp/login'
    - ログインに使われます。




config-hww.txtのサンプル
============================================

以下は自分がそのまま使っている設定です。
詳細なサンプルはconfig-hww.txt.sampleを参照してください。


    # config.txtを読み込まない
    no_load_config_hw:1
    # ユーザネームとパスワードをConfig::Pitから読み込み
    load_from_pit:1

    # デフォルト
    txt_dir:text/tyru-entry
    touch_file:text/tyru-entry/touch.txt
    client_encoding:utf-8
    server_encoding:euc-jp
    use_cookie:1
    editor:gvim

    # vimグループ特有の設定
    group.vim.groupname:vim
    group.vim.txt_dir:text/vim
    group.vim.touch_file:text/vim/touch.txt
    group.vim.server_encoding:utf-8

    # twitterグループ特有の設定
    group.twitter.groupname:twitter
    group.twitter.txt_dir:text/twitter
    group.twitter.touch_file:text/twitter/touch.txt
    group.twitter.server_encoding:utf-8

    # alias
    alias.g:group
    alias.gh:gen-html
    alias.ui:update-index
    alias.sh:shell
    alias.ed:editor
    alias.ve:verify
    alias.ah:apply-headline
    alias.rh:revert-headline

    alias.debug:config is_debug




要望やバグ報告
============================================

tyru.exe@gmail.comまでどうぞ。
それか[twitter](http://twitter.com/tyru)からでもどうぞ。(リプライは遅めです)
自分の環境だとうまくいかないだとかインストールできないよ！なども気軽に相談ください。お願いします。
