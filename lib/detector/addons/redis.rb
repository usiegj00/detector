require 'redis'

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
    end
  end
  
  # Register the addon
  Base.register_addon(:redis, Addons::Redis)
end 