require "spec_helper"

RSpec.describe Detector::Addons::Redis do
  let(:uri) { "redis://localhost:6379/0" }
  let(:detector) { Detector.detect(uri) }

  describe "#connection" do
    it "creates a Redis connection" do
      allow(Redis).to receive(:new).and_return(double)
      expect(detector.connection).not_to be_nil
    end
  end

  describe "#info" do
    it "returns Redis server info" do
      connection = double
      redis_info = {"redis_version" => "6.2.1", "role" => "master"}
      allow(detector).to receive(:connection).and_return(connection)
      allow(connection).to receive(:info).and_return(redis_info)
      
      expect(detector.info).to eq(redis_info)
    end
  end

  describe "#replication_available?" do
    context "when server is a master" do
      it "returns true" do
        connection = double
        redis_info = {"role" => "master"}
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_return(redis_info)
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when server has connected slaves" do
      it "returns true" do
        connection = double
        redis_info = {"role" => "slave", "connected_slaves" => "2"}
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_return(redis_info)
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when slave read-only mode is disabled" do
      it "returns true" do
        connection = double
        redis_info = {"role" => "slave", "connected_slaves" => "0", "slave_read_only" => "0"}
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_return(redis_info)
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when no replication is configured" do
      it "returns false" do
        connection = double
        redis_info = {"role" => "slave", "connected_slaves" => "0", "slave_read_only" => "1"}
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_return(redis_info)
        
        expect(detector.replication_available?).to be false
      end
    end
    
    context "when connection fails" do
      it "returns nil" do
        allow(detector).to receive(:connection).and_return(nil)
        expect(detector.replication_available?).to be nil
      end
    end
    
    context "when an error occurs" do
      it "returns nil" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_raise(Redis::ConnectionError)
        
        expect(detector.replication_available?).to be nil
      end
    end
  end
end 