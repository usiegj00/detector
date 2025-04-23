require "spec_helper"

RSpec.describe Detector do
  it "has a version number" do
    expect(Detector::VERSION).not_to be nil
  end

  describe ".detect" do
    it "returns nil for invalid URIs" do
      expect(Detector.detect("not_a_uri")).to be_nil
    end

    it "detects postgres URI" do
      detector = Detector.detect("postgres://user:pass@localhost:5432/mydb")
      expect(detector).not_to be_nil
      expect(detector.kind).to eq(:postgres)
    end

    it "detects redis URI" do
      detector = Detector.detect("redis://localhost:6379")
      expect(detector).not_to be_nil
      expect(detector.kind).to eq(:redis)
    end

    it "detects mysql URI" do
      detector = Detector.detect("mysql://user:pass@localhost:3306/mydb")
      expect(detector).not_to be_nil
      expect(detector.kind).to eq(:mysql)
    end

    it "detects mariadb URI" do
      detector = Detector.detect("mariadb://user:pass@localhost:3306/mydb")
      expect(detector).not_to be_nil
      expect(detector.kind).to eq(:mariadb)
    end

    it "detects smtp URI" do
      detector = Detector.detect("smtp://user:pass@smtp.example.com:25")
      expect(detector).not_to be_nil
      expect(detector.kind).to eq(:smtp)
    end
  end
end 