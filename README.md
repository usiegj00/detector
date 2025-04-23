# Detector

A Ruby gem for detecting and analyzing various database systems. Detector is a system manager's toolkit that helps you quickly check database stats and structure.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'detector'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install detector
```

## Usage

### CLI

```
$ detector "postgres://user:pass@host:port/dbname"
```

This will display:
- Database system type
- Version
- Database count
- For the 3 largest databases:
  - Table count
  - The 3 largest tables with row counts

### Ruby API

```ruby
require 'detector'

# Create a detector for a database
db = Detector.detect("postgres://user:pass@host:port/dbname")

# Get basic info
db.kind          # => :postgres
db.host          # => "host"
db.port          # => 5432
db.version       # => "PostgreSQL 12.1 on x86_64-pc-linux-gnu, ..."

# Detect infrastructure
db.infrastructure # => "Amazon Web Services", "Google Cloud Platform", etc.

# Geographic information
db.geography     # => "Ashburn, Virginia, United States"
db.region        # => "us-east-1"
db.asn           # => "AS16509"

# Get database stats
db.database_count  # => 5
db.databases       # => [{ name: "db1", size: "1.2 GB", ... }, ...]

# Get table stats (requires database name)
db_name = db.databases.first[:name]  # Or any database you want to inspect
db.table_count(db_name)   # => 42 
db.tables(db_name)        # => [{ name: "users", row_count: 10000, size: "500 MB", ... }, ...]
```

## Supported Systems

- PostgreSQL
- MySQL
- MariaDB
- Redis
- SMTP

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).