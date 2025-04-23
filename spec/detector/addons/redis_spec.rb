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
        allow(detector).to receive(:info).and_return(nil)
        allow(connection).to receive(:info).and_raise(Redis::ConnectionError)
        
        expect(detector.replication_available?).to be nil
      end
    end
  end

  describe "#estimated_row_count" do
    context "when keys are found" do
      it "returns the count of matching keys" do
        connection = double
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:scan).with("0", match: "user:*", count: 1000).and_return(["0", ["user:1", "user:2", "user:3"]])
        
        expect(detector.estimated_row_count(table: "user:*")).to eq(3)
      end
    end
    
    context "when using a specific database" do
      it "selects the database before counting" do
        connection = double
        
        allow(detector).to receive(:connection).and_return(connection)
        expect(connection).to receive(:select).with(2)
        allow(connection).to receive(:scan).with("0", match: "user:*", count: 1000).and_return(["0", ["user:1", "user:2"]])
        
        expect(detector.estimated_row_count(table: "user:*", database: "2")).to eq(2)
      end
    end
    
    context "when an error occurs" do
      it "returns nil" do
        connection = double
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:scan).and_raise(Redis::ConnectionError)
        
        expect(detector.estimated_row_count(table: "user:*")).to be_nil
      end
    end
  end
  
  describe "#close" do
    context "when connection exists" do
      it "quits and clears the connection" do
        connection = double
        
        # Directly stub the instance variable
        detector.instance_variable_set(:@conn, connection)
        
        # Expect quit to be called (Redis uses quit instead of close)
        expect(connection).to receive(:quit)
        
        detector.close
        
        # Verify the connection was cleared
        expect(detector.instance_variable_get(:@conn)).to be_nil
      end
    end
    
    context "when connection is nil" do
      it "handles nil connection gracefully" do
        detector.instance_variable_set(:@conn, nil)
        expect { detector.close }.not_to raise_error
      end
    end
    
    context "when quit raises an error" do
      it "rescues the error" do
        connection = double
        detector.instance_variable_set(:@conn, connection)
        
        allow(connection).to receive(:quit).and_raise(Redis::ConnectionError)
        
        expect { detector.close }.not_to raise_error
      end
    end
  end
end 