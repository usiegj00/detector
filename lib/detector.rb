require 'uri'
require 'resolv'
require 'detector/version'
require 'detector/base'
require 'detector/addons/postgres'
require 'detector/addons/redis'
require 'detector/addons/mysql'
require 'detector/addons/mariadb'
require 'detector/addons/smtp'

module Detector
  class Error < StandardError; end

  def self.detect(uri_string)
    Base.detect(uri_string)
  end
end 