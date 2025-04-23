require "spec_helper"

RSpec.describe Detector::Base do
  let(:base) { Detector::Base.new('http://example.com') }

  describe "#table_count" do
    context "when the addon supports tables" do
      before do
        allow(base).to receive(:valid?).and_return(true)
        allow(base).to receive(:tables?).and_return(true)
        allow(base).to receive(:connection?).and_return(true)
      end
      
      it "returns the total count of tables across all databases" do
        db1 = { name: 'db1' }
        db2 = { name: 'db2' }
        
        allow(base).to receive(:databases).and_return([db1, db2])
        allow(base).to receive(:tables).with(db1).and_return([{name: 'table1'}, {name: 'table2'}])
        allow(base).to receive(:tables).with(db2).and_return([{name: 'table3'}])
        
        expect(base.table_count).to eq(3)
      end
      
      it "returns nil if there are no tables" do
        allow(base).to receive(:databases).and_return([{name: 'db1'}])
        allow(base).to receive(:tables).with({name: 'db1'}).and_return([])
        
        expect(base.table_count).to be_nil
      end
    end
    
    context "when the addon doesn't support tables" do
      it "returns nil" do
        allow(base).to receive(:valid?).and_return(true)
        allow(base).to receive(:tables?).and_return(false)
        
        expect(base.table_count).to be_nil
      end
    end
    
    context "when not valid" do
      it "returns nil" do
        allow(base).to receive(:valid?).and_return(false)
        
        expect(base.table_count).to be_nil
      end
    end
    
    context "when no connection" do
      it "returns nil" do
        allow(base).to receive(:valid?).and_return(true)
        allow(base).to receive(:tables?).and_return(true)
        allow(base).to receive(:connection?).and_return(false)
        
        expect(base.table_count).to be_nil
      end
    end
  end
  
  describe "#replication_available?" do
    it "returns nil by default" do
      expect(base.replication_available?).to be_nil
    end
  end
  
  describe "#estimated_row_count" do
    it "returns nil by default" do
      expect(base.estimated_row_count(table: 'test')).to be_nil
    end
  end
  
  describe "#close" do
    it "does nothing by default" do
      # The base implementation just returns nil, so make sure it doesn't error
      expect { base.close }.not_to raise_error
    end
  end
  
  describe "#connection_count" do
    it "returns nil by default" do
      expect(base.connection_count).to be_nil
    end
  end
  
  describe "#connection_limit" do
    it "returns nil by default" do
      expect(base.connection_limit).to be_nil
    end
  end
  
  describe "#connection_usage_percentage" do
    context "when connection stats are available" do
      it "calculates the percentage correctly" do
        allow(base).to receive(:connection_count).and_return(50)
        allow(base).to receive(:connection_limit).and_return(100)
        
        expect(base.connection_usage_percentage).to eq(50.0)
      end
    end
    
    context "when connection stats are not available" do
      it "returns nil when connection_count is missing" do
        allow(base).to receive(:connection_count).and_return(nil)
        allow(base).to receive(:connection_limit).and_return(100)
        
        expect(base.connection_usage_percentage).to be_nil
      end
      
      it "returns nil when connection_limit is missing" do
        allow(base).to receive(:connection_count).and_return(50)
        allow(base).to receive(:connection_limit).and_return(nil)
        
        expect(base.connection_usage_percentage).to be_nil
      end
      
      it "returns nil when connection_limit is zero" do
        allow(base).to receive(:connection_count).and_return(50)
        allow(base).to receive(:connection_limit).and_return(0)
        
        expect(base.connection_usage_percentage).to be_nil
      end
    end
  end
end 