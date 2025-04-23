require 'net/smtp'

module Detector
  module Addons
    class SMTP < Base
      def self.handles_uri?(uri)
        uri.scheme.downcase == 'smtp' || uri.scheme.downcase == 'smtps'
      end
      
      def self.capabilities_for(url)
        { kv: true, sql: false, url: url, kind: :smtp, databases: false, tables: false }
      end
    
      def connection
        return @conn if @conn
        
        begin
          @conn = Net::SMTP.new(host, port)
          @conn.open_timeout = 5
          @conn.start('detector.local', uri.user, uri.password, :login)
          @conn
        rescue => e
          nil
        end
      end
      
      def version
        return nil unless connection
        "SMTP server at #{host}:#{port}"
      end
      
      def cli_name
        "telnet"
      end
    end
  end
  
  # Register the addon
  Base.register_addon(:smtp, Addons::SMTP)
end 