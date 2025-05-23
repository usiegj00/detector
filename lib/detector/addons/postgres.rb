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
        # Create a new connection each time without caching
        PG::Connection.new(uri) rescue nil
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
        result = []
        
        # Get the list of databases and their sizes
        db_list = connection.exec("SELECT datname, pg_size_pretty(pg_database_size(datname)) as size, 
                                   pg_database_size(datname) as raw_size 
                                   FROM pg_database 
                                   WHERE datistemplate = false 
                                   ORDER BY raw_size DESC")
        
        # For each database, get table count
        db_list.each do |row|
          db_name = row['datname']
          
          # Skip system databases or databases we can't connect to
          next if ['postgres', 'template0', 'template1'].include?(db_name)
          
          # Get table count for this database
          table_count = 0
          
          begin
            # Create a temporary connection to count tables
            temp_conn = PG::Connection.new(host: host, port: port, user: uri.user, 
                                          password: uri.password, dbname: db_name) rescue nil
                                          
            if temp_conn
              table_count = temp_conn.exec("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'").first['count'].to_i
              temp_conn.close
            end
          rescue
            # Skip if we can't connect
            next
          end
          
          result << { 
            name: db_name, 
            size: row['size'], 
            raw_size: row['raw_size'].to_i,
            table_count: table_count
          }
        end
        
        @databases = result
      end
      
      def connection_count
        return nil unless connection
        connection.exec("SELECT count(*) FROM pg_stat_activity").first['count'].to_i
      end
      
      def connection_limit
        return nil unless connection
        connection.exec("SELECT current_setting('max_connections')").first['current_setting'].to_i
      end
      
      def connection_info
        return nil unless connection
        begin
          global_limit = connection.exec("SELECT current_setting('max_connections')").first['current_setting'].to_i
          global_count = connection.exec("SELECT count(*) FROM pg_stat_activity").first['count'].to_i
          
          # For PostgreSQL user connections - depends on per-user limits if set
          user_limit_result = connection.exec("SELECT rolconnlimit FROM pg_roles WHERE rolname = current_user").first
          user_limit = user_limit_result['rolconnlimit'].to_i
          user_limit = global_limit if user_limit <= 0 # If unlimited, use global limit
          
          user_count = connection.exec("SELECT count(*) FROM pg_stat_activity WHERE usename = current_user").first['count'].to_i
          
          {
            connection_count: { user: user_count, global: global_count },
            connection_limits: { user: user_limit, global: global_limit }
          }
        rescue => e
          nil
        end
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
      
      def replication_available?
        return nil unless connection
        
        begin
          replication_roles = connection.exec("SELECT rolname, rolreplication FROM pg_roles WHERE rolreplication = true;")
          !replication_roles.values.empty?
        rescue => e
          nil
        end
      end
      
      def estimated_row_count(table:, database: nil)
        return nil unless connection
        
        # Use the current database if none is specified
        db_name = database || current_database
        
        begin
          # If we need to query a different database, temporarily connect to it
          if db_name != current_database
            # Create a temporary connection to the specified database
            temp_conn = PG::Connection.new(host: host, port: port, user: uri.user, 
                                         password: uri.password, dbname: db_name) rescue nil
            return nil unless temp_conn
            
            # Use pg_class.reltuples for a fast, statistics-based row estimate
            count = temp_conn.exec("SELECT reltuples::bigint AS estimate 
                                  FROM pg_class 
                                  WHERE relname = '#{table}'").first
            temp_conn.close
            return count ? count['estimate'].to_i : nil
          end
          
          # Query the current database using pg_class.reltuples
          count = connection.exec("SELECT reltuples::bigint AS estimate 
                                FROM pg_class 
                                WHERE relname = '#{table}'").first
          
          count ? count['estimate'].to_i : nil
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
  Base.register_addon(:postgres, Addons::Postgres)
end 