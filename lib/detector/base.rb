require 'socket'
require 'geocoder'
require_relative 'region'
require_relative 'vendor'

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
    
    def geo
      return nil unless valid?
      @geo ||= Geocoder.search(ip).first
    end
    
    # Lookup the location for the IP:
    def geography
      return nil unless valid?
      "#{geo.city}, #{geo.region}, #{geo.country}" if geo
    end
    
    def region
      return nil unless valid?
      Region.detect_region(host, geo)
    end
    
    def asn
      return nil unless valid?
      geo&.data&.dig('org')&.split(" ")&.first
    end
    
    def connection?
      connection.present?
    end
    
    def connection
      nil
    end
    
    def ping
      return nil unless valid?
      transport?
    end
    
    def transport?
      protocol_type == :tcp ? tcp_test : udp_test
    end
    
    # Should be implemented by subclasses
    def protocol_type
      :tcp # Default to TCP
    end
    
    def tcp_test
      return nil unless ip && port
      begin
        socket = TCPSocket.new(ip, port)
        socket.close
        true
      rescue => e
        nil
      end
    end
    
    def udp_test
      return nil unless ip && port
      begin
        socket = UDPSocket.new
        socket.connect(ip, port)
        socket.send("", 0) # Send empty packet as probe
        socket.close
        true
      rescue => e
        nil
      end
    end
    
    def table_count
      return nil unless valid? && tables? && connection?
      
      count = 0
      database_list = databases
      
      database_list.each do |db|
        count += tables(db).size
      end
      
      count.zero? ? nil : count
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
    
    def user_access_level
      return nil unless valid? && connection?
      "Unknown"
    end
    
    def infrastructure
      return nil unless valid?
      
      provider = Vendor.detect_provider(host)
      return provider if provider
      
      # If geo data available, return organization, otherwise nil
      geo&.data&.dig('org')
    end
    
    def replication_available?
      nil
    end
    
    def connection_count
      nil
    end
    
    def connection_limit
      nil
    end
    
    def connection_usage_percentage
      return nil unless connection_count && connection_limit && connection_limit > 0
      (connection_count.to_f / connection_limit.to_f * 100).round(1)
    end
    
    def estimated_row_count(table:, database: nil)
      nil
    end
  end
end 