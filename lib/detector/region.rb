module Detector
  class Region
    class << self
      def detect_region(host, geo)
        return nil unless host || geo
        
        hostname = host.to_s.downcase
        
        # Try to determine region from hostname first
        aws_region = detect_aws_region(hostname)
        return aws_region if aws_region
        
        azure_region = detect_azure_region(hostname)
        return azure_region if azure_region
        
        gcp_region = detect_gcp_region(hostname)
        return gcp_region if gcp_region
        
        # Fallbacks to geocoder data
        return nil unless geo
        
        # Try city-based detection
        city_region = detect_region_by_city(geo&.data&.dig('city')&.downcase)
        return city_region if city_region
        
        # Try region/country based detection
        geo_region = detect_region_by_geography(geo&.data&.dig('region'), geo&.data&.dig('country'))
        return geo_region if geo_region
        
        # Final fallback
        geo&.data&.dig('region') || geo&.data&.dig('country_code')&.downcase
      end
      
      private
      
      def detect_aws_region(hostname)
        return nil unless hostname =~ /amazonaws\.com/ || hostname =~ /aws/
        
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
        
        nil
      end
      
      def detect_azure_region(hostname)
        return nil unless hostname =~ /azure|windows\.net|cloudapp/
        
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
        
        nil
      end
      
      def detect_gcp_region(hostname)
        return nil unless hostname =~ /google|googlecloud|gcp|appspot/
        
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
        
        nil
      end
      
      def detect_region_by_city(city)
        return nil unless city
        
        case city
        when 'ashburn', 'sterling', 'herndon', 'chantilly'
          "us-east-1" # AWS us-east-1 or equivalent
        when 'columbus', 'dublin', 'hilliard'
          "us-east-2" # AWS us-east-2
        when 'san jose', 'santa clara', 'milpitas', 'fremont'
          "us-west-1" # AWS us-west-1
        when 'portland', 'hillsboro', 'prineville', 'the dalles'
          "us-west-2" # AWS us-west-2 / GCP us-west1
        when 'phoenix', 'tempe', 'mesa'
          "westus3" # Azure westus3
        when 'dallas', 'fort worth', 'san antonio'
          "southcentralus" # Azure southcentralus
        when 'montreal', 'beauharnois', 'quebec'
          "ca-central-1" # AWS ca-central-1
        when 'toronto'
          "canadacentral" # Azure canadacentral
        when 'frankfurt', 'munich'
          "eu-central-1" # AWS eu-central-1
        when 'london'
          "eu-west-2" # AWS eu-west-2
        when 'paris'
          "eu-west-3" # AWS eu-west-3
        when 'dublin', 'clondalkin'
          "eu-west-1" # AWS eu-west-1
        when 'stockholm'
          "eu-north-1" # AWS eu-north-1
        when 'milan'
          "eu-south-1" # AWS eu-south-1
        when 'sydney', 'melbourne'
          "ap-southeast-2" # AWS ap-southeast-2
        when 'singapore'
          "ap-southeast-1" # AWS ap-southeast-1
        when 'tokyo', 'osaka'
          "ap-northeast-1" # AWS ap-northeast-1
        when 'seoul'
          "ap-northeast-2" # AWS ap-northeast-2
        when 'mumbai'
          "ap-south-1" # AWS ap-south-1
        when 'hong kong'
          "ap-east-1" # AWS ap-east-1
        when 'são paulo', 'sao paulo'
          "sa-east-1" # AWS sa-east-1
        else
          nil
        end
      end
      
      def detect_region_by_geography(region_name, country)
        return nil unless region_name || country
        
        if country == 'United States'
          case region_name
          when 'Virginia', 'Maryland', 'District of Columbia'
            "us-east-1"
          when 'Ohio', 'Indiana', 'Michigan'
            "us-east-2"
          when 'California'
            "us-west-1"
          when 'Oregon', 'Washington', 'Idaho'
            "us-west-2"
          when 'Nevada', 'Utah', 'Arizona'
            "us-west-2"
          when 'Texas', 'Oklahoma', 'Louisiana'
            "southcentralus"
          when 'Illinois', 'Iowa', 'Minnesota', 'Missouri', 'Wisconsin'
            "us-central1"
          else
            nil
          end
        elsif country == 'Canada'
          case region_name
          when 'Quebec'
            "ca-central-1"
          when 'Ontario'
            "canadacentral"
          else
            nil
          end
        elsif country == 'Brazil'
          "sa-east-1"
        elsif country == 'Ireland'
          "eu-west-1"
        elsif country == 'United Kingdom'
          "eu-west-2"
        elsif country == 'France'
          "eu-west-3"
        elsif country == 'Germany'
          "eu-central-1"
        elsif country == 'Sweden' || country == 'Norway' || country == 'Finland'
          "eu-north-1"
        elsif country == 'Italy'
          "eu-south-1"
        elsif country == 'India'
          "ap-south-1"
        elsif country == 'Singapore'
          "ap-southeast-1"
        elsif country == 'Australia'
          "ap-southeast-2"
        elsif country == 'Japan'
          "ap-northeast-1"
        elsif country == 'South Korea'
          "ap-northeast-2"
        elsif country == 'Hong Kong'
          "ap-east-1"
        else
          nil
        end
      end
    end
  end
end 