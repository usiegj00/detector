module Detector
  class Vendor
    class << self
      def detect_provider(hostname)
        return nil unless hostname
        
        hostname = hostname.to_s.downcase
        
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
          nil
        end
      end
    end
  end
end 