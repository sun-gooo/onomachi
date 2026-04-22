-- Redmine 本番用データベース
CREATE DATABASE IF NOT EXISTS `redmine`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Redmine 検証環境用データベース
CREATE DATABASE IF NOT EXISTS `redmine_test`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
