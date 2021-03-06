
require File.expand_path("../spec_helper", __dir__)

class HttpTestRequest
  attr_accessor :calls

  def initialize
    self.calls = []
  end

  [:via, :basic_auth, :auth].each do |method|
    define_method method do |*args|
      dup.tap do |request|
        request.calls = calls + [[method, args]]
      end
    end
  end
end

RSpec.describe SearchFlip::HTTPClient do
  describe "delegation" do
    subject { SearchFlip::HTTPClient }

    [:headers, :via, :basic_auth, :auth].each do |method|
      it { should delegate(method).to(:new) }
    end

    [:get, :post, :put, :delete, :head].each do |method|
      it { should delegate(method).to(:new) }
    end
  end

  [:get, :put, :delete, :post, :head].each do |method|
    describe "##{method}" do
      it "performs the specified request" do
        stub_request(method, "http://localhost/path").with(body: "body", query: { key: "value" }).to_return(body: "success")

        expect(SearchFlip::HTTPClient.new.send(method, "http://localhost/path", body: "body", params: { key: "value" }).body.to_s).to eq("success")
      end
    end
  end

  [:via, :basic_auth, :auth].each do |method|
    describe "##{method}" do
      it "creates a dupped instance" do
        client = SearchFlip::HTTPClient.new
        client.request = HttpTestRequest.new

        client1 = client.send(method, "key1")
        client2 = client1.send(method, "key2")

        expect(client1.object_id).not_to eq(client2.object_id)
      end

      it "extends the request" do
        client = SearchFlip::HTTPClient.new
        client.request = HttpTestRequest.new

        client1 = client.send(method, "key1")
        client2 = client1.send(method, "key2")

        expect(client1.request.calls).to eq([[method, ["key1"]]])
        expect(client2.request.calls).to eq([[method, ["key1"]], [method, ["key2"]]])
      end
    end
  end
end
