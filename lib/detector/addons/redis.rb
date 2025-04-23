require 'redis'
require 'timeout'

module Detector
  module Addons
    class Redis < Base
      def self.handles_uri?(uri)
        uri.scheme.downcase == 'redis' || uri.scheme.downcase == 'rediss'
      end
      
      def self.capabilities_for(url)
        { kv: true, sql: false, url: url, kind: :redis, databases: true, tables: false }
      end
    
      def connection
        return @conn if @conn
        
        if uri.scheme == 'rediss'
          @conn = ::Redis.new(url: @url, port: uri.port, timeout: 5.0, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }) rescue nil
        else
          @conn = ::Redis.new(url: @url, timeout: 5.0) rescue nil
        end
      end
      
      def info
        return nil unless connection
        @info ||= connection.info
      end
      
      def version
        return nil unless info
        "Redis #{info['redis_version']} on #{info['os']} #{info['arch']}, compiled by #{info['gcc_version']}, #{info['arch_bits']}-bit"
      end
      
      def usage
        return nil unless info
        
        per = (info['used_memory'].to_f / info['maxmemory'].to_f) * 100
        percent = sprintf("%.2f%%", per)
        "#{info['used_memory_human']} of #{info['maxmemory_human']} used (#{percent})" rescue -1
      end
      
      def database_count
        return nil unless connection
        connection.info['keyspace'].keys.size
      end
      
      def databases
        return [] unless info && info['keyspace']
        
        info['keyspace'].map do |db_name, stats|
          keys, expires = stats.split(',').map { |s| s.split('=').last.to_i }
          { name: db_name, keys: keys, expires: expires, stats: stats }
        end.sort_by { |db| -db[:keys] }
      end
      
      def table_count
        return nil unless connection
        connection.dbsize rescue 0
      end
      
      def connection_count
        return nil unless info
        info['connected_clients'].to_i rescue 0
      end
      
      def connection_limit
        return nil unless info
        info['maxclients'].to_i rescue 0
      end
      
      def cli_name
        "redis-cli"
      end
      
      def protocol_type
        :tcp
      end
      
      def user_access_level
        return nil unless connection
        
        # Redis 6.0+ supports ACLs, older versions just have auth or no auth
        redis_version = info['redis_version'].to_s
        
        if Gem::Version.new(redis_version) >= Gem::Version.new('6.0.0')
          begin
            acl_info = connection.call('ACL', 'LIST')
            default_user = acl_info.grep(/default/).first
            
            if default_user.include?('on') && default_user.include?('nopass')
              return "Administrator (open access)"
            elsif default_user.include?('on') && default_user.include?('~*')
              return "Administrator (password protected)"
            elsif default_user.include?('allkeys')
              if default_user.include?('allcommands')
                return "Full access (all commands, all keys)"
              else
                return "Limited command access (all keys)"
              end
            else
              if default_user.include?('reset')
                "No access (default rights)"
              else
                "Custom ACL pattern"
              end
            end
          rescue => e
            # Try to determine rights by test commands for older Redis
            self.generic_redis_access_check
          end
        else
          # Older Redis version
          self.generic_redis_access_check
        end
      end
      
      def generic_redis_access_check
        # Check for admin commands
        admin_access = false
        begin
          # Try an admin command (CONFIG GET)
          connection.call('CONFIG', 'GET', 'maxmemory')
          admin_access = true
        rescue => e
          admin_access = false
        end
        
        # Check for write ability
        write_access = false
        begin
          # Use a random key name to avoid conflicts
          test_key = "__test_key_#{rand(1000000)}"
          connection.call('SET', test_key, 'test_value')
          connection.call('DEL', test_key)
          write_access = true
        rescue => e
          write_access = false
        end
        
        if admin_access
          "Administrator (config access)"
        elsif write_access
          "Regular user (read/write)"
        else
          # Try a read command
          begin
            connection.call('PING')
            "Read-only user"
          rescue => e
            "Limited access"
          end
        end
      end
      
      def replication_available?
        return nil unless connection && info
        
        begin
          # Check if this is a master in a replication setup
          if info['role'] == 'master'
            return true
          end
          
          # Check if server has replication enabled
          if info['connected_slaves'].to_i > 0 || info['slave_read_only'] == '0'
            return true
          end
          
          false
        rescue => e
          nil
        end
      end
      
      def estimated_row_count(table:, database: nil)
        return nil unless connection
        
        # In Redis, the database is a number (0-15 typically) and "table" concept is closest to key patterns
        # We'll interpret table parameter as a key pattern
        
        begin
          # Set the database if specified
          if database
            # Redis db numbers are integers
            db_num = database.to_s.gsub(/[^0-9]/, '').to_i
            connection.select(db_num) rescue nil
          end
          
          # Count keys matching the pattern (consider this a heuristic approximation)
          # Use SCAN for larger datasets, as it doesn't block the server
          count = 0
          cursor = "0"
          
          begin
            # Timeout after a reasonable time to prevent long-running operations
            Timeout.timeout(5) do
              loop do
                cursor, keys = connection.scan(cursor, match: table, count: 1000)
                count += keys.size
                break if cursor == "0"
              end
            end
          rescue Timeout::Error
            # If we time out, return the partial count with a note
            return count
          end
          
          count
        rescue => e
          nil
        end
      end
      
      def close
        if @conn
          @conn.quit rescue nil
          @conn = nil
        end
      end
    end
  end
  
  # Register the addon
  Base.register_addon(:redis, Addons::Redis)
end 