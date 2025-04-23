require 'mysql2'

module Detector
  module Addons
    class MySQL < Base
      def self.handles_uri?(uri)
        uri.scheme.downcase == 'mysql'
      end
      
      def self.capabilities_for(url)
        { sql: true, kv: true, url: url, kind: :mysql, databases: true, tables: true }
      end
    
      def connection
        # Create a new connection each time without caching
        # Handle URI path correctly - strip leading slash if present
        db_name = uri.path ? uri.path.sub(/^\//, '') : nil
        
        Mysql2::Client.new(
          host: host,
          username: uri.user,
          password: uri.password,
          database: db_name,
          port: port,
          connect_timeout: 5,
          read_timeout: 10,
          write_timeout: 10,
          init_command: "SET wait_timeout=900; SET interactive_timeout=900;"
        ) rescue nil
      end
      
      def info
        return nil unless connection
        @info ||= connection.query("SELECT VERSION() AS version, DATABASE() AS `database`, USER() AS user").first
      end
      
      def version
        return nil unless info
        "MySQL #{info['version']} on #{info['database']} (#{info['user']})"
      end
      
      def usage
        return nil unless connection && info
        result = connection.query("SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size FROM information_schema.TABLES WHERE table_schema = '#{info['database']}'").first
        "#{result['size']} MB"
      end
      
      def database_count
        return nil unless connection
        @database_count ||= connection.query("SELECT COUNT(*) AS count FROM information_schema.SCHEMATA WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')").first['count']
      end
      
      def databases
        return [] unless connection
        @databases ||= connection.query("SELECT 
                                      schema_name AS name,
                                      FORMAT(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb,
                                      SUM(data_length + index_length) AS raw_size,
                                      COUNT(table_name) AS table_count
                                      FROM information_schema.SCHEMATA
                                      LEFT JOIN information_schema.TABLES ON table_schema = schema_name
                                      WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                                      GROUP BY schema_name
                                      ORDER BY raw_size DESC").map do |row|
          { 
            name: row['name'], 
            size: "#{row['size_mb']} MB", 
            raw_size: row['raw_size'].to_i,
            table_count: row['table_count'].to_i
          }
        end
      end
      
      def table_count(database_name)
        return nil unless connection
        connection.query("SELECT COUNT(*) AS count FROM information_schema.TABLES WHERE table_schema = '#{database_name}'").first['count']
      end
      
      def tables(database_name)
        return [] unless connection
        
        @tables ||= {}
        @tables[database_name] ||= connection.query("SELECT table_name AS name, 
                                                   FORMAT((data_length + index_length) / 1024 / 1024, 2) AS size_mb,
                                                   (data_length + index_length) AS raw_size,
                                                   table_rows AS row_count
                                                   FROM information_schema.TABLES 
                                                   WHERE table_schema = '#{database_name}'
                                                   ORDER BY raw_size DESC").map do |row|
          { name: row['name'], size: "#{row['size_mb']} MB", raw_size: row['raw_size'].to_i, row_count: row['row_count'].to_i }
        end
      end
      
      def connection_count
        return nil unless connection
        connection.query("SELECT COUNT(*) AS count FROM information_schema.PROCESSLIST").first['count']
      end
      
      def connection_limit
        return nil unless connection
        connection.query("SHOW VARIABLES LIKE 'max_connections'").first['Value'].to_i
      end
      
      def connection_info
        return nil unless connection
        begin
          user_limit = connection.query("SELECT @@max_user_connections AS `limit`").first['limit'].to_i
          user_count = connection.query("SELECT COUNT(*) AS count FROM information_schema.PROCESSLIST WHERE user = USER()").first['count'].to_i
          global_limit = connection.query("SELECT @@max_connections AS `limit`").first['limit'].to_i
          global_count = connection.query("SELECT COUNT(*) AS count FROM information_schema.PROCESSLIST").first['count'].to_i
          
          # If user limit is 0, it means no specific per-user limit (use global)
          user_limit = global_limit if user_limit == 0
          
          {
            connection_count: { user: user_count, global: global_count },
            connection_limits: { user: user_limit, global: global_limit }
          }
        rescue Mysql2::Error => e
          if e.error_number == 1226 # User has exceeded max_user_connections
            {
              connection_count: { user: "LIMIT EXCEEDED", global: "N/A" },
              connection_limits: { user: "EXCEEDED", global: "N/A" },
              error: "Error: User has exceeded max_user_connections limit"
            }
          else
            nil
          end
        rescue => e
          nil
        end
      end
      
      def cli_name
        "mysql"
      end
      
      def protocol_type
        :tcp
      end
      
      def user_access_level
        return nil unless connection
        
        # Get all privileges for current user
        grants = []
        begin
          result = connection.query("SHOW GRANTS FOR CURRENT_USER()")
          result.each do |row|
            grants << row.values.first
          end
        rescue => e
          return "Limited access (unable to check privileges)"
        end
        
        grant_text = grants.join(" ")
        
        # Check for root/admin privileges
        if grant_text =~ /ALL PRIVILEGES ON \*\.\* TO/i
          return "Administrator (all privileges)"
        end
        
        # Check for global privileges
        if grant_text =~ /GRANT .* ON \*\.\*/i
          global_privs = []
          global_privs << "CREATE USER" if grant_text =~ /CREATE USER/i
          global_privs << "PROCESS" if grant_text =~ /PROCESS/i
          global_privs << "SUPER" if grant_text =~ /SUPER/i
          global_privs << "RELOAD" if grant_text =~ /RELOAD/i
          global_privs << "SHUTDOWN" if grant_text =~ /SHUTDOWN/i
          
          if global_privs.include?("CREATE USER") || global_privs.include?("SUPER")
            return "Power user (#{global_privs.join(", ")})"
          elsif !global_privs.empty?
            return "System monitor (#{global_privs.join(", ")})"
          end
        end
        
        # Check for database-level privileges
        db_with_all = []
        if grant_text =~ /ALL PRIVILEGES ON (`[^`]+`|\w+)\./i
          db_name = $1.gsub(/`/, "")
          db_with_all << db_name
        end
        
        if !db_with_all.empty?
          return "Database admin (full access to: #{db_with_all.join(", ")})"
        end
        
        # Check for specific privileges
        can_write = grant_text =~ /INSERT|UPDATE|DELETE|CREATE|ALTER|DROP/i
        can_read = grant_text =~ /SELECT/i
        
        if can_write
          "Write access"
        elsif can_read
          "Read-only access"
        else
          "Limited access"
        end
      end
      
      def replication_available?
        return nil unless connection
        
        begin
          # Check master status
          master_result = connection.query("SHOW MASTER STATUS")
          return true if master_result.count > 0
          
          # Check if this is a slave
          slave_result = connection.query("SHOW SLAVE STATUS")
          return true if slave_result.count > 0
          
          # Check if replication user exists or if binary logging is enabled
          repl_users = connection.query("SELECT user FROM mysql.user WHERE Repl_slave_priv = 'Y'")
          return true if repl_users.count > 0
          
          # Check if binary logging is enabled (needed for replication)
          binary_log = connection.query("SHOW VARIABLES LIKE 'log_bin'").first
          return true if binary_log && binary_log['Value'] && binary_log['Value'].downcase == 'on'
          
          false
        rescue => e
          nil
        end
      end
      
      def estimated_row_count(table:, database: nil)
        return nil unless connection
        
        # Use current database if none specified
        db_name = database || info['database']
        return nil unless db_name
        
        begin
          # Query information_schema.tables for the statistics-based row estimate
          result = connection.query("SELECT table_rows AS estimate 
                                   FROM information_schema.tables 
                                   WHERE table_schema = '#{db_name}' 
                                   AND table_name = '#{table}'").first
          
          result ? result['estimate'].to_i : nil
        rescue => e
          nil
        end
      end
      
      def close
        if @conn
          @conn.close rescue nil
          @conn = nil
        end
      end
    end
  end
  
  # Register the addon
  Base.register_addon(:mysql, Addons::MySQL)
end 