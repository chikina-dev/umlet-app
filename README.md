# UMLet for macOS

Homebrew版UMLetをFinderから起動し、`.uxf` ファイルを開くためのmacOS 12以降向けの `.app` ラッパーです。
Apple SiliconとIntelに対応します。

## インストール

`brew install umlet` でUMLet本体をインストールしてから、[Releases](https://github.com/chikina-dev/umlet-app/releases) の `UMLet.dmg` を開き、アプリをApplicationsへドラッグします。
`.uxf` の関連付けは、Finderの「情報を見る」→「このアプリケーションで開く」でUMLetを選び、「すべてを変更」で設定します。
配布アプリはアドホック署名で、Appleの公証は行いません。

## DMGの作成

GitHub Actionsの「Build DMG」を手動実行すると、成果物から `UMLet.dmg` をダウンロードできます。
`v` で始まるタグをpushすると、ReleaseへDMGを添付します。

```sh
git tag v1.0.0
git push origin v1.0.0
```

アイコンは [UMLet](https://github.com/umlet/umlet) の画像から生成したもので、ライセンスは [UMLet-LICENSE.txt](Resources/UMLet-LICENSE.txt) に収録しています。
