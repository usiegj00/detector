require "spec_helper"

RSpec.describe Detector::Addons::MySQL do
  let(:uri) { "mysql://user:pass@localhost:3306/mydb" }
  let(:detector) { Detector.detect(uri) }

  describe "#connection" do
    it "creates a MySQL connection" do
      allow(Mysql2::Client).to receive(:new).and_return(double)
      expect(detector.connection).not_to be_nil
    end
  end

  describe "#version" do
    it "returns version info" do
      connection = double
      info = {"version" => "8.0.25", "database" => "mydb", "user" => "user@localhost"}
      allow(detector).to receive(:connection).and_return(connection)
      allow(detector).to receive(:info).and_return(info)
      
      expect(detector.version).to eq("MySQL 8.0.25 on mydb (user@localhost)")
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

  describe "#estimated_row_count" do
    context "when table exists" do
      it "returns the estimated row count" do
        connection = double
        info = {"database" => "mydb"}
        result = {"estimate" => 1000}
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_return(info)
        allow(connection).to receive(:query).with(
          "SELECT table_rows AS estimate \n                                   FROM information_schema.tables \n                                   WHERE table_schema = 'mydb' \n                                   AND table_name = 'users'"
        ).and_return([result])
        
        expect(detector.estimated_row_count(table: "users")).to eq(1000)
      end
    end
    
    context "when an error occurs" do
      it "returns nil" do
        connection = double
        info = {"database" => "mydb"}
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:info).and_return(info)
        allow(connection).to receive(:query).and_raise(Mysql2::Error)
        
        expect(detector.estimated_row_count(table: "users")).to be_nil
      end
    end
  end
  
  describe "#close" do
    context "when connection exists" do
      it "closes and clears the connection" do
        connection = double
        
        # Directly stub the instance variable
        detector.instance_variable_set(:@conn, connection)
        
        # Expect close to be called
        expect(connection).to receive(:close)
        
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
    
    context "when close raises an error" do
      it "rescues the error" do
        connection = double
        detector.instance_variable_set(:@conn, connection)
        
        allow(connection).to receive(:close).and_raise(StandardError)
        
        expect { detector.close }.not_to raise_error
      end
    end
  end
end 