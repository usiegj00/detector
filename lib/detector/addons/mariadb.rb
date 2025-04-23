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
    
      def connection
        # Override the MySQL connection method with MariaDB-specific settings
        # Handle URI path correctly - strip leading slash if present
        db_name = uri.path ? uri.path.sub(/^\//, '') : nil
        
        begin
          # MariaDB-specific connection with fixed init command syntax
          Mysql2::Client.new(
            host: host,
            username: uri.user,
            password: uri.password,
            database: db_name,
            port: port,
            connect_timeout: 15,
            read_timeout: 30,
            write_timeout: 30
            # MariaDB doesn't like multiple statements in init_command
          )
        rescue Mysql2::Error => e
          puts "MariaDB connection error: #{e.message}" if ENV['DETECTOR_DEBUG']
          nil
        rescue => e
          puts "General connection error: #{e.class} - #{e.message}" if ENV['DETECTOR_DEBUG']
          nil
        end
      end
      
      def info
        return nil unless connection
        begin
          connection.query("SELECT VERSION() AS version, DATABASE() AS `database`, USER() AS user").first
        rescue Mysql2::Error => e
          if e.error_number == 1226 # User has exceeded max_user_connections
            {
              'version' => 'Unknown (exceeded connections)',
              'database' => uri.path ? uri.path.sub(/^\//, '') : 'unknown',
              'user' => "#{uri.user}@exceeded"
            }
          else
            nil
          end
        rescue => e
          nil
        end
      end
      
      def version
        return nil unless info
        begin
          "MariaDB #{info['version']} on #{info['database']} (#{info['user']})"
        rescue => e
          "MariaDB (connection error: #{e.message})"
        end
      end
      
      def databases
        return [] unless connection
        begin
          # First get all databases
          db_list = connection.query("SELECT schema_name AS name 
                                     FROM information_schema.SCHEMATA 
                                     WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')").map do |row|
            row['name']
          end
          
          # For each database, get its size
          result = []
          db_list.each do |db_name|
            size_query = "SELECT 
                            IFNULL(FORMAT(SUM(data_length + index_length) / 1024 / 1024, 2), '0.00') AS size_mb,
                            IFNULL(SUM(data_length + index_length), 0) AS raw_size,
                            COUNT(table_name) AS table_count
                          FROM information_schema.TABLES 
                          WHERE table_schema = '#{db_name}'"
            
            size_data = connection.query(size_query).first
            result << { 
              name: db_name, 
              size: "#{size_data['size_mb']} MB", 
              raw_size: size_data['raw_size'].to_i,
              table_count: size_data['table_count'].to_i
            }
          end
          
          # Sort by size
          @databases = result.sort_by { |db| -db[:raw_size] }
        rescue => e
          puts "Error getting databases: #{e.message}"
          []
        end
      end
      
      def connection_info
        return {
          connection_count: { user: "LIMIT EXCEEDED", global: "N/A" },
          connection_limits: { user: "EXCEEDED", global: "N/A" },
          error: "Error: User has exceeded max_user_connections limit"
        } if connection.nil? && (ENV['DETECTOR_DEBUG'] && ENV['DETECTOR_DEBUG'].include?('exceeded'))
        
        # Try to get connection info as normal
        super
      end
      
      def tables(database_name)
        return [] unless connection
        
        begin
          @tables ||= {}
          @tables[database_name] ||= connection.query("SELECT 
                                                 table_name AS name, 
                                                 IFNULL(FORMAT((data_length + index_length) / 1024 / 1024, 2), '0.00') AS size_mb,
                                                 IFNULL((data_length + index_length), 0) AS raw_size,
                                                 IFNULL(table_rows, 0) AS row_count
                                                 FROM information_schema.TABLES 
                                                 WHERE table_schema = '#{database_name}'
                                                 ORDER BY raw_size DESC").map do |row|
            { 
              name: row['name'], 
              size: "#{row['size_mb']} MB", 
              raw_size: row['raw_size'].to_i, 
              row_count: row['row_count'].to_i 
            }
          end
        rescue => e
          puts "Error getting tables for #{database_name}: #{e.message}"
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