require "spec_helper"

RSpec.describe Detector::Addons::Postgres do
  let(:uri) { "postgres://user:pass@localhost:5432/mydb" }
  let(:detector) { Detector.detect(uri) }

  describe "#connection" do
    it "creates a PG connection" do
      allow(PG::Connection).to receive(:new).and_return(double)
      expect(detector.connection).not_to be_nil
    end
  end

  describe "#version" do
    it "returns version info" do
      connection = double
      result = double
      allow(detector).to receive(:connection).and_return(connection)
      allow(connection).to receive(:exec).with("SELECT version()").and_return([{"version" => "PostgreSQL 12.1"}])
      expect(detector.version).to eq("PostgreSQL 12.1")
    end
  end

  describe "#databases" do
    it "returns database list" do
      connection = double
      result = [
        {"datname" => "db1", "size" => "100 MB", "raw_size" => "10000"},
        {"datname" => "db2", "size" => "200 MB", "raw_size" => "20000"}
      ]
      allow(detector).to receive(:connection).and_return(connection)
      allow(connection).to receive(:exec).and_return(result)
      
      expect(detector.databases.size).to eq(2)
      expect(detector.databases.first[:name]).to eq("db1")
    end
  end
  
  describe "#replication_available?" do
    context "when replication roles exist" do
      it "returns true" do
        connection = double
        replication_roles = double
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:exec)
          .with("SELECT rolname, rolreplication FROM pg_roles WHERE rolreplication = true;")
          .and_return(replication_roles)
        allow(replication_roles).to receive(:values).and_return([["repl_user", "t"]])
        
        expect(detector.replication_available?).to be true
      end
    end
    
    context "when no replication roles exist" do
      it "returns false" do
        connection = double
        replication_roles = double
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:exec)
          .with("SELECT rolname, rolreplication FROM pg_roles WHERE rolreplication = true;")
          .and_return(replication_roles)
        allow(replication_roles).to receive(:values).and_return([])
        
        expect(detector.replication_available?).to be false
      end
    end
    
    context "when an error occurs" do
      it "returns nil" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(connection).to receive(:exec)
          .with("SELECT rolname, rolreplication FROM pg_roles WHERE rolreplication = true;")
          .and_raise(PG::Error)
        
        expect(detector.replication_available?).to be nil
      end
    end
  end
  
  describe "#estimated_row_count" do
    context "when querying the current database" do
      it "returns the estimated row count" do
        connection = double
        count_result = {"estimate" => "1000"}
        
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:current_database).and_return("mydb")
        allow(connection).to receive(:exec)
          .with("SELECT reltuples::bigint AS estimate \n                                FROM pg_class \n                                WHERE relname = 'users'")
          .and_return([count_result])
        
        expect(detector.estimated_row_count(table: "users")).to eq(1000)
      end
    end
    
    context "when an error occurs" do
      it "returns nil" do
        connection = double
        allow(detector).to receive(:connection).and_return(connection)
        allow(detector).to receive(:current_database).and_return("mydb")
        allow(connection).to receive(:exec).and_raise(PG::Error)
        
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