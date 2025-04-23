require 'socket'
require 'geocoder'

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
      
      # Try to determine region from hostname first
      hostname = host.to_s.downcase
      
      # AWS regions from hostname
      if hostname =~ /amazonaws\.com/ || hostname =~ /aws/
        return "us-east-1" if hostname =~ /us-east-1|virginia|nova/
        return "us-east-2" if hostname =~ /us-east-2|ohio/
        return "us-west-1" if hostname =~ /us-west-1|california|norcal/
        return "us-west-2" if hostname =~ /us-west-2|oregon/
        return "af-south-1" if hostname =~ /af-south|cape-town/
        return "ap-east-1" if hostname =~ /ap-east|hong-kong/
        return "ap-south-1" if hostname =~ /ap-south|mumbai/
        return "ap-northeast-1" if hostname =~ /ap-northeast-1|tokyo/
        return "ap-northeast-2" if hostname =~ /ap-northeast-2|seoul/
        return "ap-northeast-3" if hostname =~ /ap-northeast-3|osaka/
        return "ap-southeast-1" if hostname =~ /ap-southeast-1|singapore/
        return "ap-southeast-2" if hostname =~ /ap-southeast-2|sydney/
        return "ca-central-1" if hostname =~ /ca-central|canada|montreal/
        return "eu-central-1" if hostname =~ /eu-central-1|frankfurt/
        return "eu-west-1" if hostname =~ /eu-west-1|ireland|dublin/
        return "eu-west-2" if hostname =~ /eu-west-2|london/
        return "eu-west-3" if hostname =~ /eu-west-3|paris/
        return "eu-north-1" if hostname =~ /eu-north-1|stockholm/
        return "eu-south-1" if hostname =~ /eu-south-1|milan/
        return "me-south-1" if hostname =~ /me-south-1|bahrain/
        return "sa-east-1" if hostname =~ /sa-east-1|sao-paulo/
      end
      
      # Azure regions from hostname
      if hostname =~ /azure|windows\.net|cloudapp/
        return "eastus" if hostname =~ /eastus|virginia/
        return "eastus2" if hostname =~ /eastus2/
        return "centralus" if hostname =~ /centralus|iowa/
        return "northcentralus" if hostname =~ /northcentralus|illinois/
        return "southcentralus" if hostname =~ /southcentralus|texas/
        return "westus" if hostname =~ /westus|california/
        return "westus2" if hostname =~ /westus2|washington/
        return "westus3" if hostname =~ /westus3|phoenix/
        return "australiaeast" if hostname =~ /australiaeast|sydney/
        return "brazilsouth" if hostname =~ /brazilsouth|sao-paulo/
        return "canadacentral" if hostname =~ /canadacentral|toronto/
        return "centralindia" if hostname =~ /centralindia|pune/
        return "eastasia" if hostname =~ /eastasia|hong-kong/
        return "francecentral" if hostname =~ /francecentral|paris/
        return "germanywestcentral" if hostname =~ /germanywestcentral|frankfurt/
        return "japaneast" if hostname =~ /japaneast|tokyo/
        return "koreacentral" if hostname =~ /koreacentral|seoul/
        return "northeurope" if hostname =~ /northeurope|ireland/
        return "southeastasia" if hostname =~ /southeastasia|singapore/
        return "southindia" if hostname =~ /southindia|chennai/
        return "swedencentral" if hostname =~ /swedencentral|stockholm/
        return "switzerlandnorth" if hostname =~ /switzerlandnorth|zurich/
        return "uksouth" if hostname =~ /uksouth|london/
        return "westeurope" if hostname =~ /westeurope|netherlands/
      end
      
      # Google Cloud regions from hostname
      if hostname =~ /google|googlecloud|gcp|appspot/
        return "us-central1" if hostname =~ /us-central1|iowa/
        return "us-east1" if hostname =~ /us-east1|south-carolina/
        return "us-east4" if hostname =~ /us-east4|virginia/
        return "us-west1" if hostname =~ /us-west1|oregon/
        return "us-west2" if hostname =~ /us-west2|los-angeles/
        return "us-west3" if hostname =~ /us-west3|salt-lake-city/
        return "us-west4" if hostname =~ /us-west4|las-vegas/
        return "northamerica-northeast1" if hostname =~ /northamerica-northeast1|montreal/
        return "southamerica-east1" if hostname =~ /southamerica-east1|sao-paulo/
        return "europe-west1" if hostname =~ /europe-west1|belgium/
        return "europe-west2" if hostname =~ /europe-west2|london/
        return "europe-west3" if hostname =~ /europe-west3|frankfurt/
        return "europe-west4" if hostname =~ /europe-west4|netherlands/
        return "europe-west6" if hostname =~ /europe-west6|zurich/
        return "europe-north1" if hostname =~ /europe-north1|finland/
        return "asia-east1" if hostname =~ /asia-east1|taiwan/
        return "asia-east2" if hostname =~ /asia-east2|hong-kong/
        return "asia-northeast1" if hostname =~ /asia-northeast1|tokyo/
        return "asia-northeast2" if hostname =~ /asia-northeast2|osaka/
        return "asia-northeast3" if hostname =~ /asia-northeast3|seoul/
        return "asia-south1" if hostname =~ /asia-south1|mumbai/
        return "asia-southeast1" if hostname =~ /asia-southeast1|singapore/
        return "asia-southeast2" if hostname =~ /asia-southeast2|jakarta/
        return "australia-southeast1" if hostname =~ /australia-southeast1|sydney/
      end
      
      # Fallback to IP-based lookup via Geocoder
      return nil unless geo
      
      # City-based detection for common cloud cities
      city = geo&.data&.dig('city')&.downcase
      if city
        case city
        when 'ashburn', 'sterling', 'herndon', 'chantilly'
          return "us-east-1" # AWS us-east-1 or equivalent
        when 'columbus', 'dublin', 'hilliard'
          return "us-east-2" # AWS us-east-2
        when 'san jose', 'santa clara', 'milpitas', 'fremont'
          return "us-west-1" # AWS us-west-1
        when 'portland', 'hillsboro', 'prineville', 'the dalles'
          return "us-west-2" # AWS us-west-2 / GCP us-west1
        when 'phoenix', 'tempe', 'mesa'
          return "westus3" # Azure westus3
        when 'dallas', 'fort worth', 'san antonio'
          return "southcentralus" # Azure southcentralus
        when 'montreal', 'beauharnois', 'quebec'
          return "ca-central-1" # AWS ca-central-1
        when 'toronto'
          return "canadacentral" # Azure canadacentral
        when 'frankfurt', 'munich'
          return "eu-central-1" # AWS eu-central-1
        when 'london'
          return "eu-west-2" # AWS eu-west-2
        when 'paris'
          return "eu-west-3" # AWS eu-west-3
        when 'dublin', 'clondalkin'
          return "eu-west-1" # AWS eu-west-1
        when 'stockholm'
          return "eu-north-1" # AWS eu-north-1
        when 'milan'
          return "eu-south-1" # AWS eu-south-1
        when 'sydney', 'melbourne'
          return "ap-southeast-2" # AWS ap-southeast-2
        when 'singapore'
          return "ap-southeast-1" # AWS ap-southeast-1
        when 'tokyo', 'osaka'
          return "ap-northeast-1" # AWS ap-northeast-1
        when 'seoul'
          return "ap-northeast-2" # AWS ap-northeast-2
        when 'mumbai'
          return "ap-south-1" # AWS ap-south-1
        when 'hong kong'
          return "ap-east-1" # AWS ap-east-1
        when 'são paulo', 'sao paulo'
          return "sa-east-1" # AWS sa-east-1
        end
      end
      
      # Region/State-based mapping to approximate cloud region
      region_name = geo&.data&.dig('region')
      country = geo&.data&.dig('country')
      
      if country == 'United States'
        case region_name
        when 'Virginia', 'Maryland', 'District of Columbia'
          return "us-east-1"
        when 'Ohio', 'Indiana', 'Michigan'
          return "us-east-2"
        when 'California'
          return "us-west-1"
        when 'Oregon', 'Washington', 'Idaho'
          return "us-west-2"
        when 'Nevada', 'Utah', 'Arizona'
          return "us-west-2"
        when 'Texas', 'Oklahoma', 'Louisiana'
          return "southcentralus"
        when 'Illinois', 'Iowa', 'Minnesota', 'Missouri', 'Wisconsin'
          return "us-central1"
        end
      elsif country == 'Canada'
        case region_name
        when 'Quebec'
          return "ca-central-1"
        when 'Ontario'
          return "canadacentral"
        end
      elsif country == 'Brazil'
        return "sa-east-1"
      elsif country == 'Ireland'
        return "eu-west-1"
      elsif country == 'United Kingdom'
        return "eu-west-2"
      elsif country == 'France'
        return "eu-west-3"
      elsif country == 'Germany'
        return "eu-central-1"
      elsif country == 'Sweden' || country == 'Norway' || country == 'Finland'
        return "eu-north-1"
      elsif country == 'Italy'
        return "eu-south-1"
      elsif country == 'India'
        return "ap-south-1"
      elsif country == 'Singapore'
        return "ap-southeast-1"
      elsif country == 'Australia'
        return "ap-southeast-2"
      elsif country == 'Japan'
        return "ap-northeast-1"
      elsif country == 'South Korea'
        return "ap-northeast-2"
      elsif country == 'Hong Kong'
        return "ap-east-1"
      end
      
      # Final fallback
      region_name || geo&.data&.dig('country_code')&.downcase
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
    
    def user_access_level
      return nil unless valid? && connection?
      "Unknown"
    end
    
    def infrastructure
      return nil unless valid?
      
      hostname = host.to_s.downcase
      case hostname
      when /amazon/, /aws/, /amazonaws/, /ec2/, /s3/, /dynamodb/, /rds\./, /elasticbeanstalk/
        "Amazon Web Services"
      when /google/, /googlecloud/, /appspot/, /gcp/, /compute\./, /cloud\.g/
        "Google Cloud Platform"
      when /azure/, /azurewebsites/, /cloudapp\./, /windows\.net/
        "Microsoft Azure"
      when /antimony/
        "Build.io"
      when /heroku/, /herokuapp/
        "Heroku"
      when /digitalocean/, /droplet/
        "DigitalOcean"
      when /linode/, /linodeobjects/
        "Linode"
      when /vultr/
        "Vultr"
      when /netlify/
        "Netlify"
      when /vercel/, /zeit\.co/, /now\.sh/
        "Vercel"
      when /github\.io/, /githubusercontent/, /github\.dev/
        "GitHub"
      when /gitlab\.io/, /gitlab-static/
        "GitLab"
      when /oracle/, /oraclecloud/
        "Oracle Cloud"
      when /ibm/, /bluemix/, /ibmcloud/
        "IBM Cloud"
      when /cloudflare/, /workers\.dev/
        "Cloudflare"
      when /fastly/
        "Fastly"
      when /akamai/
        "Akamai"
      when /render\.com/
        "Render"
      when /fly\.io/
        "Fly.io"
      when /railway\.app/
        "Railway"
      when /upcloud/
        "UpCloud"
      when /hetzner/
        "Hetzner"
      when /ovh/, /ovhcloud/
        "OVH"
      when /scaleway/
        "Scaleway"
      when /contabo/
        "Contabo"
      when /dreamhost/
        "DreamHost"
      when /hostgator/
        "HostGator"
      when /bluehost/
        "Bluehost"
      when /siteground/
        "SiteGround"
      when /namecheap/
        "Namecheap"
      when /godaddy/
        "GoDaddy"
      when /ionos/
        "IONOS"
      when /hostinger/
        "Hostinger"
      else
        # If geo data available, return organization, otherwise nil
        geo&.data&.dig('org')
      end
    end
  end
end 