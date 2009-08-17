
= Hatena Diary Writer Wrapper って何？

Hatena Diary Writerをラップしてさまざまな機能を加えたものです。
略称は個人的にはどうでもいいですが

- はてなダイアリーライターラッパー (そのまま)
- はてだらっぱー
- hww (スクリプト名hww.plから)

とか呼んでいます。
このドキュメントでは短いのでhwwで統一します。


= Hatena Diary Writer(通称はてダラ) って何？

オリジナルのはてダラの配布元は、作者である結城浩さんのサイトですが、
hwwは、そのはてダラを使い易くしようとRakefileを加えた
こせきさん(id:koseki)のリポジトリからforkしたものです。

- http://github.com/koseki/hatenadiary-writer/


以下に結城浩さんによるはてダラの説明の引用を載せます。
なおこの説明は次のURLでも読むことができます。

- http://www.hyuki.com/techinfo/hatena_diary_writer.html


> はてなダイアリーは、Webブラウザから書き込みができ、手軽で便利な日記（ブログ）サービスです。
>
> でも、以下のような場合には、Webブラウザでいちいち書き込みをするのは面倒です。
>
> - Webブラウザ上ではなく、自分のテキストエディタで日記を書きたい。
> - ネットにつながっていないときにオフラインで日記を書きたい。
> - 書き込む日記がサーバだけにあるのはいやだ、ローカルにもファイルとして持ちたい。たとえばローカルで検索したい(grepをかけたい)から。
> - 過去の日記のあちこちをこまかく直して、まとめて送信したい。
>
> そこで、 ローカルに作った「2004-08-19.txt」のようなテキストファイルの内容を、 はてなダイアリーの「2004年8月19日の日記」として書き込むPerlスクリプトを書きました。
>
> それが「はてなダイアリーライター」（略称：はてダラ）です。
>
> テキストファイルのタイムスタンプを自動判定し、 新しく作ったファイル、 再編集したファイルだけをはてなダイアリーに送信します。
>
> 「はてダラ」はフリーソフトウェアです。 バグなどのご報告は大歓迎します。 ライセンスはPerlと同じです。
>
> なお、このツール「はてダラ」は結城が独自に作成したものです。 株式会社はてなへの問い合わせはご遠慮ください。



= どんなことができるのか

hwwは、具体的には次のようなコマンドを持っています。(2009-08-17 現在)
次のうちいくつかの操作ははてダラでも可能です。


- apply-headline
  - rename if modified headlines
- chain
  - chain commands with '--'
- copyright
- diff
- gen-html
  - generate htmls from entry files
- help
  - display help information about hww
init
- load
  - load entries from hatena diary
- release
  - upload entries to hatena diary
- revert-headline
- shell
- status - show information about entry files
- touch
  - update 'touch.txt'
- truncate
- update
  - upload entries to hatena diary as trivial
- update-index
  - make html from template file by HTML::Template
- verify
  - verify misc information
- version
  - display version information about hww


