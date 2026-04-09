# Onomachi Docker 開発環境

Nginx Gateway を経由して、Redmine・WordPress・phpMyAdmin を同一ホスト（ポート 80）で動作させる Docker Compose 環境です。

## 構成

| サービス | コンテナ名 | イメージ / ビルド | 説明 |
|---|---|---|---|
| db | onomachi-it-media-db | mysql:8.0 | 共通 MySQL データベース |
| gateway | gateway-nginx | nginx:latest | リバースプロキシ（エントリポイント） |
| redmine | redmine-app | redmine:latest | プロジェクト管理ツール |
| wp-php | wp-php-app | php:8.4-fpm（ビルド） | WordPress PHP-FPM |
| wp-nginx | wp-nginx-server | nginx:latest | WordPress 用 Nginx |
| phpmyadmin | it-media-pma | phpmyadmin:latest | DB 管理ツール |

## 前提条件

- Docker および Docker Compose がインストールされていること
- ポート **80** が空いていること

## 環境変数の設定

プロジェクトルートに `.env` ファイルを作成し、以下の変数を設定してください。

```env
MYSQL_ROOT_PASSWORD=root_pass

DB_NAME_WP=wp_db
DB_USER_WP=wp_user
DB_PASSWORD_WP=wp_pass
```

> **重要**: `MYSQL_ROOT_PASSWORD` が未設定だと MySQL コンテナが起動に失敗し、phpMyAdmin や Redmine など DB に依存するサービスがすべて動作しません。

## 起動方法

```bash
# コンテナをビルド＆起動
docker compose up -d

# コンテナの状態を確認
docker compose ps
```

## 停止方法

```bash
# コンテナを停止・削除
docker compose down

# データベースのボリュームも含めて完全に削除する場合
docker compose down -v
```

## 各アプリケーションの URL

| アプリケーション | URL |
|---|---|
| Redmine | http://localhost/redmine |
| WordPress | http://localhost/onomachi-it-media |
| phpMyAdmin | http://localhost/phpmyadmin/ |

> phpMyAdmin の URL は末尾のスラッシュ (`/`) が必要です。

## 注意点

- **`.env` ファイルは Git で管理しないでください。** パスワード等の機密情報が含まれるため、`.gitignore` に追加することを推奨します。
- **DB データの永続化**: MySQL のデータは Docker ボリューム `db_data` に保存されます。`docker compose down -v` を実行するとデータが削除されるため注意してください。
- **WordPress ファイル**: `wordpress/onomachi-it-media/html/` がホストにマウントされています。ここにソースコードの変更を加えると即座にコンテナに反映されます。
- **Redmine ファイル**: `redmine/data/` に添付ファイルが保存されます。
- **PHP 設定**: `wordpress/onomachi-it-media/php/php.ini` でカスタム PHP 設定を変更できます。
- **Nginx 設定**:
  - Gateway: `gateway/default.conf`
  - WordPress 用: `wordpress/onomachi-it-media/nginx/default.conf`
- **コンテナの再ビルド**: WordPress の PHP Dockerfile (`wordpress/onomachi-it-media/php/Dockerfile`) を変更した場合は、`docker compose up -d --build` で再ビルドが必要です。