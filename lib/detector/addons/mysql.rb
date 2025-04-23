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
        @conn ||= Mysql2::Client.new(
          host: host,
          username: uri.user,
          password: uri.password,
          database: uri.path[1..-1],
          port: port
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
        @databases ||= connection.query("SELECT schema_name AS name,
                                      FORMAT(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb,
                                      SUM(data_length + index_length) AS raw_size
                                      FROM information_schema.SCHEMATA
                                      JOIN information_schema.TABLES ON table_schema = schema_name
                                      WHERE schema_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
                                      GROUP BY schema_name
                                      ORDER BY raw_size DESC").map do |row|
          { name: row['name'], size: "#{row['size_mb']} MB", raw_size: row['raw_size'].to_i }
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
      
      def cli_name
        "mysql"
      end
    end
  end
  
  # Register the addon
  Base.register_addon(:mysql, Addons::MySQL)
end 