require_relative 'mysql'

module Detector
  module Addons
    class MariaDB < MySQL
      def self.handles_uri?(uri)
        uri.scheme.downcase == 'mariadb'
      end
      
      def self.capabilities_for(url)
        { sql: true, kv: true, url: url, kind: :mariadb, databases: true, tables: true }
      end
      
      # Determine if an error is retriable
      def retriable_error?(error_number)
        # List of error codes that might be temporary and worth retrying
        retriable_codes = [
          1040, # Too many connections
          1053, # Server shutdown in progress
          1077, # Connection refused
          2002, # Connection refused
          2003, # Can't connect to MySQL server
          2006, # MySQL server has gone away
          2008, # Client ran out of memory
          2013, # Lost connection during query
          2026, # SSL connection error
          2055  # Lost connection to MySQL server at '%s', system error: %d
        ]
        
        retriable_codes.include?(error_number)
      end
      
      # Retry a connection with exponential backoff
      def with_retry(max_retries = 3)
        retries = 0
        
        begin
          yield
        rescue Mysql2::Error => e
          if retriable_error?(e.error_number) && retries < max_retries
            retries += 1
            wait_time = 0.5 * (2 ** retries) # Exponential backoff: 1s, 2s, 4s, etc.
            
            puts "Connection error (#{e.error_number}): #{e.message}. Retrying in #{wait_time}s (attempt #{retries}/#{max_retries})..." if ENV['DETECTOR_DEBUG']
            
            sleep(wait_time)
            retry
          else
            # Not retriable or max retries reached
            raise
          end
        end
      end
    
      # Cache for database requests
      def initialize(url)
        super
        @cache = {}
      end
    
      def connection
        # Return cached connection if already established
        return @conn if @conn && @conn.ping
        
        # Override the MySQL connection method with MariaDB-specific settings
        # Handle URI path correctly - strip leading slash if present
        db_name = uri.path ? uri.path.sub(/^\//, '') : nil
        
        begin
          # Try with retry for retriable errors
          with_retry do
            # MariaDB-specific connection with fixed init command syntax
            conn = Mysql2::Client.new(
              host: host,
              username: uri.user,
              password: uri.password,
              database: db_name,
              port: port,
              connect_timeout: 15,
              read_timeout: 30,
              write_timeout: 30,
              reconnect: true
              # No init_command - caused issues with MariaDB
            )
            
            # Test the connection with a simple query
            conn.query("SELECT 1")
            @conn = conn
          end
          
          @conn
        rescue Mysql2::Error => e
          error_message = "MariaDB connection error: #{e.message}"
          error_type = case
            when e.error_number == 1226 then "max_user_connections exceeded"
            when e.error_number == 1045 then "access denied (auth failure)"
            when e.error_number == 1049 then "unknown database '#{db_name}'"
            when e.error_number == 2003 then "server unavailable or network error"
            when e.error_number == 2005 then "unknown host"
            when e.error_number == 2006 then "server gone away"
            when e.error_number == 2013 then "connection lost"
            else "general error"
          end
          
          puts "#{error_message} [#{error_type}]" if ENV['DETECTOR_DEBUG']
          
          # Store the error information
          @cache[:connection_error] = {
            message: e.message,
            type: error_type,
            error_number: e.error_number,
            retriable: retriable_error?(e.error_number)
          }
          
          nil
        rescue => e
          # For non-MySQL errors, still capture them
          puts "General connection error: #{e.class} - #{e.message}" if ENV['DETECTOR_DEBUG']
          @cache[:connection_error] = {
            message: e.message,
            type: "general error",
            error_number: 0,
            retriable: false
          }
          nil
        end
      end
      
      # Method to execute queries with retry for retriable errors
      def execute_query(query)
        return nil unless connection
        
        begin
          with_retry do
            connection.query(query)
          end
        rescue => e
          puts "Query execution error: #{e.message}" if ENV['DETECTOR_DEBUG']
          nil
        end
      end
      
      def connection_error
        @cache[:connection_error]
      end
      
      def info
        # Cache the info to avoid repeated queries
        return @cache[:info] if @cache[:info]
        
        # If we have a database and user but no connection, return basic info with error details
        if connection.nil? && uri.path && uri.user
          db_name = uri.path.sub(/^\//, '')
          error_msg = connection_error ? " (#{connection_error[:type]})" : " (connection issue)"
          
          @cache[:info] = {
            'version' => "Unknown#{error_msg}",
            'database' => db_name,
            'user' => "#{uri.user}@remote"
          }
          return @cache[:info]
        end
        
        # Otherwise try to get info from connection
        return nil unless connection
        begin
          result = execute_query("SELECT VERSION() AS version, DATABASE() AS `database`, USER() AS user")
          @cache[:info] = result ? result.first : nil
          return @cache[:info]
        rescue Mysql2::Error => e
          error_type = case
            when e.error_number == 1226 then "max_user_connections exceeded"
            else "query error"
          end
          
          puts "MariaDB info error: #{e.message} [#{error_type}]" if ENV['DETECTOR_DEBUG']
          
          db_name = uri.path ? uri.path.sub(/^\//, '') : 'unknown'
          {
            'version' => "Unknown (#{error_type})",
            'database' => db_name,
            'user' => "#{uri.user}@error"
          }
        rescue => e
          puts "General info error: #{e.message}" if ENV['DETECTOR_DEBUG']
          nil
        end
      end
      
      def version
        # Cache the version to avoid repeated queries
        return @cache[:version] if @cache[:version]
        
        return nil unless info
        begin
          @cache[:version] = "MariaDB #{info['version']} on #{info['database']} (#{info['user']})"
          return @cache[:version]
        rescue => e
          @cache[:version] = "MariaDB (connection error: #{e.message})"
          return @cache[:version]
        end
      end
      
      def databases
        # Cache the databases to avoid repeated queries
        return @cache[:databases] if @cache[:databases]
        
        return [] unless connection
        begin
          # Get all databases at once to reduce connections
          query = "SELECT 
                    s.schema_name AS name,
                    IFNULL(FORMAT(SUM(t.data_length + t.index_length) / 1024 / 1024, 2), '0.00') AS size_mb,
                    IFNULL(SUM(t.data_length + t.index_length), 0) AS raw_size,
                    COUNT(t.table_name) AS table_count
                  FROM information_schema.SCHEMATA s
                  LEFT JOIN information_schema.TABLES t ON t.table_schema = s.schema_name
                  WHERE s.schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                  GROUP BY s.schema_name
                  ORDER BY raw_size DESC"
                  
          result = execute_query(query)
          
          if result
            db_list = result.map do |row|
              { 
                name: row['name'], 
                size: "#{row['size_mb']} MB", 
                raw_size: row['raw_size'].to_i,
                table_count: row['table_count'].to_i
              }
            end
            
            # Sort by size
            @cache[:databases] = db_list.sort_by { |db| -db[:raw_size] }
            return @cache[:databases]
          else
            return []
          end
        rescue => e
          puts "Error getting databases: #{e.message}"
          []
        end
      end
      
      def connection_info
        # Cache connection info to avoid repeated queries
        return @cache[:connection_info] if @cache[:connection_info]
        
        # If no connection is available, provide error information
        if connection.nil?
          error_msg = connection_error ? connection_error[:type] : "unknown error"
          
          @cache[:connection_info] = {
            connection_count: { user: "ERROR", global: "ERROR" },
            connection_limits: { user: "ERROR", global: "ERROR" },
            error: "Connection error: #{error_msg}"
          }
          return @cache[:connection_info]
        end
        
        # If connection is available, get actual connection info
        begin
          user_limit_result = execute_query("SELECT @@max_user_connections AS `limit`")
          user_count_result = execute_query("SELECT COUNT(*) AS count FROM information_schema.PROCESSLIST WHERE user = USER()")
          global_limit_result = execute_query("SELECT @@max_connections AS `limit`")
          global_count_result = execute_query("SELECT COUNT(*) AS count FROM information_schema.PROCESSLIST")
          
          # Check if any query failed
          if !user_limit_result || !user_count_result || !global_limit_result || !global_count_result
            return {
              connection_count: { user: "ERROR", global: "ERROR" },
              connection_limits: { user: "ERROR", global: "ERROR" },
              error: "Error executing connection info queries"
            }
          end
          
          user_limit = user_limit_result.first['limit'].to_i
          user_count = user_count_result.first['count'].to_i
          global_limit = global_limit_result.first['limit'].to_i
          global_count = global_count_result.first['count'].to_i
          
          # If user limit is 0, it means no specific per-user limit (use global)
          user_limit = global_limit if user_limit == 0
          
          @cache[:connection_info] = {
            connection_count: { user: user_count, global: global_count },
            connection_limits: { user: user_limit, global: global_limit }
          }
          return @cache[:connection_info]
        rescue Mysql2::Error => e
          error_type = case
            when e.error_number == 1226 then "max_user_connections exceeded"
            else "query error"
          end
          
          puts "MariaDB connection_info error: #{e.message} [#{error_type}]" if ENV['DETECTOR_DEBUG']
          
          @cache[:connection_info] = {
            connection_count: { user: "ERROR", global: "ERROR" },
            connection_limits: { user: "ERROR", global: "ERROR" },
            error: "Connection error: #{error_type}"
          }
          return @cache[:connection_info]
        rescue => e
          puts "General connection_info error: #{e.message}" if ENV['DETECTOR_DEBUG']
          nil
        end
      end
      
      def database_count
        # Cache database count to avoid repeated queries
        return @cache[:database_count] if @cache[:database_count]
        
        # If we have databases from cache, use the count
        if @cache[:databases]
          @cache[:database_count] = @cache[:databases].size
          return @cache[:database_count]
        end
        
        # If no connection is available but we know the database name
        if connection.nil? && uri.path
          @cache[:database_count] = 1
          return @cache[:database_count]
        end
        
        # Try to query the database
        return nil unless connection
        
        begin
          result = execute_query("SELECT COUNT(*) AS count FROM information_schema.SCHEMATA WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')")
          
          if result && result.first
            @cache[:database_count] = result.first['count']
            return @cache[:database_count]
          else
            return 0
          end
        rescue Mysql2::Error => e
          puts "Error getting database count: #{e.message} [#{e.error_number}]" if ENV['DETECTOR_DEBUG']
          
          # If this is an authentication or permission error, return 0
          if e.error_number == 1045 || e.error_number == 1044
            return 0
          end
          
          # For max connections error, assume at least 1 database
          if e.error_number == 1226 && uri.path
            return 1
          end
          
          nil
        rescue => e
          puts "General error getting database count: #{e.message}" if ENV['DETECTOR_DEBUG']
          nil
        end
      end
      
      def tables(database_name)
        # Cache tables to avoid repeated queries
        @tables ||= {}
        return @tables[database_name] if @tables[database_name]
        
        # If no connection, try to provide at least some basic info from known values
        if connection.nil? && uri.path && uri.path.sub(/^\//, '') == database_name
          # We know this is the database in the URL, so return some hardcoded data
          if @cache[:dummy_tables]
            return @cache[:dummy_tables]
          else
            # No tables data available
            return []
          end
        end
        
        return [] unless connection
        
        begin
          result = execute_query("SELECT 
                                table_name AS name, 
                                IFNULL(FORMAT((data_length + index_length) / 1024 / 1024, 2), '0.00') AS size_mb,
                                IFNULL((data_length + index_length), 0) AS raw_size,
                                IFNULL(table_rows, 0) AS row_count
                                FROM information_schema.TABLES 
                                WHERE table_schema = '#{database_name}'
                                ORDER BY raw_size DESC")
                                
          if result
            @tables[database_name] = result.map do |row|
              { 
                name: row['name'], 
                size: "#{row['size_mb']} MB", 
                raw_size: row['raw_size'].to_i, 
                row_count: row['row_count'].to_i 
              }
            end
            return @tables[database_name]
          else
            @tables[database_name] = []
            return []
          end
        rescue Mysql2::Error => e
          error_type = case
            when e.error_number == 1044 then "access denied to information_schema"
            when e.error_number == 1045 then "authentication failure"
            when e.error_number == 1226 then "max_user_connections exceeded"
            else "query error (#{e.error_number})"
          end
          
          puts "Error getting tables for #{database_name}: #{e.message} [#{error_type}]" if ENV['DETECTOR_DEBUG']
          
          # Store the error for debugging
          @tables[database_name] = []
          return []
        rescue => e
          puts "General error getting tables for #{database_name}: #{e.message}" if ENV['DETECTOR_DEBUG']
          []
        end
      end
      
      def cli_name
        "mariadb"
      end
      
      def user_access_level
        # Start with MySQL access level check
        access_level = super
        
        # Add MariaDB-specific details if needed
        return access_level unless connection
        
        # Check for MariaDB-specific roles (MariaDB 10.0.5+)
        begin
          result = connection.query("SELECT 1 FROM information_schema.plugins WHERE plugin_name = 'ROLES'")
          if result.count > 0
            roles_result = connection.query("SELECT CURRENT_ROLE()").first
            current_role = roles_result.values.first
            
            # If a role is active, append it to the access level
            if current_role && current_role != '' && current_role != 'NONE'
              return "#{access_level} (Role: #{current_role})"
            end
          end
        rescue => e
          # Role system not available or not accessible to user
        end
        
        access_level
      end
      
      # MariaDB inherits the estimated_row_count method from MySQL, but we might want to override
      # with MariaDB-specific optimizations or different statistics approaches in the future
      
      # MariaDB inherits the close method from MySQL
    end
  end
  
  # Register the addon
  Base.register_addon(:mariadb, Addons::MariaDB)
end 