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
end 