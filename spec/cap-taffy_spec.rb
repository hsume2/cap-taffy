require File.join(File.dirname(__FILE__), %w[spec_helper])

describe CapTaffy do
  it "should get the version" do
    CapTaffy::VERSION.should == CapTaffy.version
  end
end
