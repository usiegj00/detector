require 'socket'

module Detector
  class Base
    @@addons = {}
    
    def self.register_addon(kind, klass)
      @@addons[kind] = klass
    end
    
    def self.detect(val)
      return nil unless val =~ /\A#{URI::regexp}\z/
      
      begin
        uri = URI.parse(val)
      rescue => e
        puts "Error parsing URI: #{e.class} #{e.message}"
        return nil
      end
      
      # Try each registered addon to see if it can handle this URI
      @@addons.each do |kind, klass|
        if klass.handles_uri?(uri)
          detector = klass.new(val)
          return detector if detector.valid?
        end
      end
      
      # Fallback to generic handling if no addon matched
      nil
    end
    
    # Default implementation to be overridden by subclasses
    def self.handles_uri?(uri)
      false
    end
    
    # Default implementation to get capabilities, should be overridden by subclasses
    def self.capabilities_for(url)
      nil
    end

    def initialize(url)
      @url = url
      @capabilities = self.class.capabilities_for(url)
      @keys = []
    end
    
    attr_accessor :uri, :keys
    
    def sql?
      valid? && @capabilities[:sql]
    end
    
    def valid?
      @capabilities && @capabilities[:kind]
    end
    
    def kind
      @capabilities && @capabilities[:kind]
    end
    
    def databases?
      @capabilities && @capabilities[:databases]
    end
    
    def tables?
      @capabilities && @capabilities[:tables]
    end
    
    def summary
      return "Invalid URI" unless valid?
      "#{kind} in #{host}"
    end
    
    def uri
      @uri ||= URI.parse(@url)
    end
    
    def host
      return nil unless valid?
      uri.host
    end
    
    def port
      return nil unless valid?
      uri.port
    end
    
    def ip
      return nil unless valid?
      Resolv.getaddress(host)
    rescue
      nil
    end
    
    def connection?
      connection.present?
    end
    
    def connection
      nil
    end
    
    def ping
      return nil unless valid?
      tcp_test
    end
    
    def tcp_test
      TCPSocket.new(ip, port).present? rescue nil
    end
    
    def table_count
      nil
    end
    
    def database_count
      nil
    end
    
    def databases
      []
    end
    
    def tables(database_name)
      []
    end
    
    def cli_name
      nil
    end
    
    def version
      nil
    end
    
    def usage
      nil
    end
  end
end 