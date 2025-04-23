# Changelog

## 0.2.1 (2025-04-24)

* Added Detector gem version to CLI output

## 0.2.0 (2025-04-24)

* Added user access level detection for all database types
* Added logger and ostruct dependencies for Ruby 3.5.0 compatibility
* Enhanced region detection with support for 70+ cloud regions from AWS, Azure, and GCP
* Added geographic location and ASN detection
* Added infrastructure detection for 30+ cloud providers
* Updated Redis dependency to support version 5.0
* Fixed version information to use VERSION constant from version.rb

## 0.1.0 (2025-04-24)

* Initial release
* Support for PostgreSQL, MySQL, MariaDB, Redis and SMTP
* Database and table statistics
* CLI tool for quick inspection 