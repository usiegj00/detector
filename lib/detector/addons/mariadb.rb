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
      
      # Override connection method to handle mariadb:// URI properly
      def connection
        @conn ||= begin
          # Convert mariadb:// scheme to mysql:// for the mysql2 gem
          mysql_url = @url.gsub(/^mariadb:\/\//, 'mysql://')
          mysql_uri = URI.parse(mysql_url)
          
          Mysql2::Client.new(
            host: host,
            username: mysql_uri.user || mysql_uri.user,
            password: mysql_uri.password || uri.password,
            database: mysql_uri.path ? mysql_uri.path[1..-1] : nil,
            port: mysql_uri.port || port
          ) 
        rescue => e
          puts "MariaDB connection error: #{e.message}" if ENV['DETECTOR_ENV'] == 'development'
          nil
        end
      end
    
      def version
        return nil unless info
        "MariaDB #{info['version']} on #{info['database']} (#{info['user']})"
      end
      
      def databases
        return use_mock_databases unless connection
        
        begin
          # First get all databases
          db_list = connection.query("SELECT schema_name AS name 
                                     FROM information_schema.SCHEMATA 
                                     WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')").map do |row|
            row['name']
          end
          
          # Handle case where no databases are found or accessible
          if db_list.empty?
            puts "No MariaDB databases found or accessible" if ENV['DETECTOR_ENV'] == 'development'
            return use_mock_databases
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
          result.sort_by { |db| -db[:raw_size] }
        rescue => e
          puts "Error getting MariaDB databases: #{e.message}" if ENV['DETECTOR_ENV'] == 'development'
          use_mock_databases
        end
      end
      
      def tables(database_name)
        return use_mock_tables(database_name) unless connection
        
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
          puts "Error getting tables for #{database_name}: #{e.message}" if ENV['DETECTOR_ENV'] == 'development'
          use_mock_tables(database_name)
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
      
      private
      
      def use_mock_databases
        # Only use mock data in test or development mode
        if ENV['DETECTOR_ENV'] == 'test' || ENV['DETECTOR_ENV'] == 'development'
          [
            { name: 'test_db', size: '100 MB', raw_size: 104857600, table_count: 5 },
            { name: 'example_db', size: '50 MB', raw_size: 52428800, table_count: 3 },
            { name: 'sample_db', size: '25 MB', raw_size: 26214400, table_count: 2 }
          ]
        else
          []
        end
      end
      
      def use_mock_tables(database_name)
        # Only use mock data in test or development mode
        if ENV['DETECTOR_ENV'] == 'test' || ENV['DETECTOR_ENV'] == 'development'
          case database_name
          when 'test_db'
            [
              { name: 'users', size: '40 MB', raw_size: 41943040, row_count: 100000 },
              { name: 'orders', size: '30 MB', raw_size: 31457280, row_count: 75000 },
              { name: 'products', size: '20 MB', raw_size: 20971520, row_count: 50000 },
              { name: 'categories', size: '5 MB', raw_size: 5242880, row_count: 1000 },
              { name: 'reviews', size: '5 MB', raw_size: 5242880, row_count: 10000 }
            ]
          when 'example_db'
            [
              { name: 'customers', size: '25 MB', raw_size: 26214400, row_count: 50000 },
              { name: 'transactions', size: '20 MB', raw_size: 20971520, row_count: 100000 },
              { name: 'accounts', size: '5 MB', raw_size: 5242880, row_count: 10000 }
            ]
          when 'sample_db'
            [
              { name: 'logs', size: '15 MB', raw_size: 15728640, row_count: 300000 },
              { name: 'config', size: '10 MB', raw_size: 10485760, row_count: 5000 }
            ]
          else
            []
          end
        else
          []
        end
      end
      
      public
    end
  end
  
  # Register the addon
  Base.register_addon(:mariadb, Addons::MariaDB)
end 