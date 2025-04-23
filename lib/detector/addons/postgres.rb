require 'pg'

module Detector
  module Addons
    class Postgres < Base
      def self.handles_uri?(uri)
        uri.scheme.downcase =~ /postgres/
      end
      
      def self.capabilities_for(url)
        { sql: true, kv: true, url: url, kind: :postgres, databases: true, tables: true }
      end
    
      def connection
        @conn ||= PG::Connection.new(uri) rescue nil
      end
      
      def version
        return nil unless connection
        @version ||= connection.exec("SELECT version()").first['version']
      end
      
      def usage
        return nil unless connection
        connection.exec("SELECT pg_size_pretty(pg_database_size(current_database())) AS size").first['size']
      end
      
      def table_count(database_name)
        return nil unless connection
        
        # If we need to query a different database, temporarily connect to it
        if database_name != current_database
          # Create a temporary connection to the specified database
          temp_conn = PG::Connection.new(host: host, port: port, user: uri.user, 
                                         password: uri.password, dbname: database_name) rescue nil
          return nil unless temp_conn
          
          count = temp_conn.exec("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'").first['count'].to_i
          temp_conn.close
          return count
        end
        
        # Query the current database
        @table_count ||= connection.exec("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'").first['count'].to_i
      end
      
      def current_database
        @current_db ||= connection.exec("SELECT current_database()").first['current_database']
      end
      
      def tables(database_name)
        return [] unless connection
        
        # If we need to query a different database, temporarily connect to it
        if database_name != current_database
          # Create a temporary connection to the specified database
          temp_conn = PG::Connection.new(host: host, port: port, user: uri.user, 
                                         password: uri.password, dbname: database_name) rescue nil
          return [] unless temp_conn
          
          result = temp_conn.exec("SELECT table_name, 
                                pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as size,
                                pg_total_relation_size(quote_ident(table_name)) as raw_size,
                                (SELECT reltuples::bigint FROM pg_class WHERE relname = table_name) as row_count
                                FROM information_schema.tables 
                                WHERE table_schema = 'public'
                                ORDER BY raw_size DESC").map do |row|
            { name: row['table_name'], size: row['size'], raw_size: row['raw_size'].to_i, row_count: row['row_count'].to_i }
          end
          
          temp_conn.close
          return result
        end
        
        # Query the current database
        @tables ||= {}
        @tables[database_name] ||= connection.exec("SELECT table_name, 
                                                 pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as size,
                                                 pg_total_relation_size(quote_ident(table_name)) as raw_size,
                                                 (SELECT reltuples::bigint FROM pg_class WHERE relname = table_name) as row_count
                                                 FROM information_schema.tables 
                                                 WHERE table_schema = 'public'
                                                 ORDER BY raw_size DESC").map do |row|
          { name: row['table_name'], size: row['size'], raw_size: row['raw_size'].to_i, row_count: row['row_count'].to_i }
        end
      end
      
      def database_count
        return nil unless connection
        @database_count ||= connection.exec("SELECT count(*) FROM pg_database WHERE datistemplate = false").first['count'].to_i
      end
      
      def databases
        return [] unless connection
        @databases ||= connection.exec("SELECT datname, pg_size_pretty(pg_database_size(datname)) as size, 
                                      pg_database_size(datname) as raw_size 
                                      FROM pg_database 
                                      WHERE datistemplate = false 
                                      ORDER BY raw_size DESC").map do |row|
          { name: row['datname'], size: row['size'], raw_size: row['raw_size'].to_i }
        end
      end
      
      def connection_count
        return nil unless connection
        connection.exec("SELECT count(*) FROM pg_stat_activity").first['count'].to_i
      end
      
      def connection_limit
        return nil unless connection
        connection.exec("SELECT current_setting('max_connections')").first['current_setting'].to_i
      end
      
      def cli_name
        "psql"
      end
      
      def protocol_type
        :tcp
      end
      
      def user_access_level
        return nil unless connection
        
        is_superuser = connection.exec("SELECT usesuper FROM pg_user WHERE usename = current_user").first["usesuper"] == "t" rescue false
        is_replication = connection.exec("SELECT rolreplication FROM pg_roles WHERE rolname = current_user").first["rolreplication"] == "t" rescue false
        roles = connection.exec("SELECT r.rolname FROM pg_roles r JOIN pg_auth_members m ON r.oid = m.roleid JOIN pg_roles u ON m.member = u.oid WHERE u.rolname = current_user").map { |row| row["rolname"] } rescue []
        
        create_db = connection.exec("SELECT usecreatedb FROM pg_user WHERE usename = current_user").first["usecreatedb"] == "t" rescue false
        
        if is_superuser
          "Superuser (full access)"
        elsif is_replication
          "Replication user (system-level replication access)"
        elsif create_db
          "Database creator (can create new databases)"
        elsif roles.include?("rds_superuser")
          "RDS Superuser (limited admin privileges)"
        else
          # Check if can access system catalogs (higher than regular user)
          begin
            connection.exec("SELECT count(*) FROM pg_shadow")
            "Power user (access to system catalogs)"
          rescue => e
            # Check if can create tables in current database
            begin
              connection.exec("CREATE TABLE __temp_access_check (id int); DROP TABLE __temp_access_check;")
              "Regular user (table management)"
            rescue => e
              # Check for readonly access
              begin
                connection.exec("SELECT current_database()")
                "Read-only user"
              rescue => e
                "Limited access"
              end
            end
          end
        end
      end
    end
  end
  
  # Register the addon
  Base.register_addon(:postgres, Addons::Postgres)
end 