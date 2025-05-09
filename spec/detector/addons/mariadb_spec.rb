require "spec_helper"

RSpec.describe Detector::Addons::MariaDB do
  let(:uri) { "mariadb://user:pass@localhost:3306/mydb" }
  let(:detector) { Detector.detect(uri) }

  describe "#connection" do
    it "creates a MariaDB connection" do
      allow(Mysql2::Client).to receive(:new).and_return(double)
      expect(detector.connection).not_to be_nil
    end
  end

  describe "#version" do
    it "returns version info" do
      connection = double
      info = {"version" => "10.6.7-MariaDB", "database" => "mydb", "user" => "user@localhost"}
      allow(detector).to receive(:connection).and_return(connection)
      allow(detector).to receive(:info).and_return(info)
      
      expect(detector.version).to eq("MariaDB 10.6.7-MariaDB on mydb (user@localhost)")
    end
  end

  describe "#replication_available?" do
    context "when server is a master" do
      it "returns true" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:query).with("SHOW MASTER STATUS").and_return([{"File" => "mysql-bin.000123"}])
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when server is a slave" do
      it "returns true" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:query).with("SHOW MASTER STATUS").and_return([])
        allow(connection).to receive(:query).with("SHOW SLAVE STATUS").and_return([{"Master_Host" => "master.example.com"}])
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when there are replication users" do
      it "returns true" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:query).with("SHOW MASTER STATUS").and_return([])
        allow(connection).to receive(:query).with("SHOW SLAVE STATUS").and_return([])
        allow(connection).to receive(:query).with("SELECT user FROM mysql.user WHERE Repl_slave_priv = 'Y'").and_return([{"user" => "repl"}])
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when only binary logging is enabled" do
      it "returns true" do
        connection = double
        binary_log = {"Value" => "ON"}
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:query).with("SHOW MASTER STATUS").and_return([])
        allow(connection).to receive(:query).with("SHOW SLAVE STATUS").and_return([])
        allow(connection).to receive(:query).with("SELECT user FROM mysql.user WHERE Repl_slave_priv = 'Y'").and_return([])
        allow(connection).to receive(:query).with("SHOW VARIABLES LIKE 'log_bin'").and_return([binary_log])
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when no replication is configured" do
      it "returns false" do
        connection = double
        binary_log = {"Value" => "OFF"}
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:query).with("SHOW MASTER STATUS").and_return([])
        allow(connection).to receive(:query).with("SHOW SLAVE STATUS").and_return([])
        allow(connection).to receive(:query).with("SELECT user FROM mysql.user WHERE Repl_slave_priv = 'Y'").and_return([])
        allow(connection).to receive(:query).with("SHOW VARIABLES LIKE 'log_bin'").and_return([binary_log])
        
        expect(detector.replication_available?).to be false
      end
    end
    
    context "when an error occurs" do
      it "returns nil" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:query).with("SHOW MASTER STATUS").and_raise(Mysql2::Error)
        
        expect(detector.replication_available?).to be nil
      end
    end
  end
end 