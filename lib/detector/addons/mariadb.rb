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
    
      def version
        return nil unless info
        "MariaDB #{info['version']} on #{info['database']} (#{info['user']})"
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
                            IFNULL(SUM(data_length + index_length), 0) AS raw_size
                          FROM information_schema.TABLES 
                          WHERE table_schema = '#{db_name}'"
            
            size_data = connection.query(size_query).first
            result << { 
              name: db_name, 
              size: "#{size_data['size_mb']} MB", 
              raw_size: size_data['raw_size'].to_i 
            }
          end
          
          # Sort by size
          @databases = result.sort_by { |db| -db[:raw_size] }
        rescue => e
          puts "Error getting databases: #{e.message}"
          []
        end
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
    end
  end
  
  # Register the addon
  Base.register_addon(:mariadb, Addons::MariaDB)
end 