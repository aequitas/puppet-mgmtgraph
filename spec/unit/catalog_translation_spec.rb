require 'spec_helper'

describe "PuppetX::CatalogTranslation" do
  describe "::to_mgmt" do
    let(:empty_catalog) { Puppet::Resource::Catalog.new }
    let(:file_catalog) do
      result = Puppet::Resource::Catalog.new
      result.add_resource(Puppet::Type.type(:file).new(
        :name => '/tmp/spec',
        :ensure => :absent
      ))
      result
    end
    let(:notify_catalog) do
      result = Puppet::Resource::Catalog.new
      result.add_resource(Puppet::Type.type(:notify).new(
        :name => 'this will not translate'
      ))
      result
    end
    let(:edge_catalog) do
      result = Puppet::Resource::Catalog.new
      result.add_resource(Puppet::Type.type(:file).new(
        :name => '/tmp/spec1',
        :ensure => :absent
      ))
      result.add_resource(Puppet::Type.type(:file).new(
        :name => '/tmp/spec2',
        :ensure => :absent,
        :require => 'File[/tmp/spec1]'
      ))
      result.add_resource(Puppet::Type.type(:notify).new(
        :name => 'this will not translate',
        :require => 'File[/tmp/spec1]'
      ))
      result
    end

    before :each do
      PuppetX::CatalogTranslation::Type.clear
    end

    it "always generates a header" do
      result = PuppetX::CatalogTranslation.to_mgmt(empty_catalog)
      expect(result).to include 'graph'
      expect(result).to include 'comment'
    end

    it "loads specific translators for resource types" do
      PuppetX::CatalogTranslation::Type.expects(:translation_for).with(:file)
      PuppetX::CatalogTranslation.to_mgmt(file_catalog)
    end

    it "does not include dropped resources in the result hash" do
      result = PuppetX::CatalogTranslation.to_mgmt(notify_catalog)
      expect(result['resources']).to_not include 'notify'
      expect(result['resources']).to_not include 'exec'
    end

    it "keeps dependency edges between supported resources" do
      result = PuppetX::CatalogTranslation.to_mgmt(edge_catalog)
      expect(result['edges'][0]).to include(
        'from' => { 'kind' => 'file', 'name' => '/tmp/spec1' },
        'to'   => { 'kind' => 'file', 'name' => '/tmp/spec2' },
      )
    end

#    # TODO: bring this back if and when we have ignored resources again
#    it "discards edges that connect to an ignored resource" do
#      # load file translator before stubbing
#      #PuppetX::CatalogTranslation::Type.translation_for(:file)
#      # make sure that no notify translator is loaded
#      #PuppetX::CatalogTranslation::Type.expects(:load_translator).with(:notify).at_least_once
#      result = PuppetX::CatalogTranslation.to_mgmt(edge_catalog)
#      #raise result['edges'].inspect
#      expect(result['edges'].length).to eq(1)
#      expect(result['edges'][0]).to_not include(
#        'to' => { 'kind' => 'notify', 'name' => 'this will not translate' },
#      )
#    end

    it "converts ruby symbols in the result to strings" do
      PuppetX::CatalogTranslation.expects(:desymbolize)
      PuppetX::CatalogTranslation.to_mgmt(empty_catalog)
    end
  end

  describe "::desymbolize" do
    { 'a string' => 'spec',
      'a symbol' => :spec,
      'an array of strings' => %w{spec test array},
      'an array of symbols' => [:spec, :test, :array],
      'a hash of strings' => { 'k' => 'v', 'x' => 'v' },
      'a hash of symbols' => { :k => :v, :x => :y },
      'a complex structure' => { :k => [ :a, :b ] } }.each do |description,value|
      context "when given #{description}" do
        it "returns strings only" do
          result = PuppetX::CatalogTranslation.desymbolize(value)
          if result.respond_to? :to_a
            result = result.to_a
          end
          [result].flatten.each do |element|
            expect(element).to be_a String
          end
        end
      end
    end
  end

  describe "::set_mode" do
    it "accepts value :optimistic" do
      expect { PuppetX::CatalogTranslation.set_mode(:optimistic) }.to_not raise_error
    end

    it "accepts value :conservative" do
      expect { PuppetX::CatalogTranslation.set_mode(:conservative) }.to_not raise_error
    end

    it "does not accept unknown parameter values" do
      [ :great, :weird, :amazing, :elastic ].each do |param|
        expect { PuppetX::CatalogTranslation.set_mode(param) }.to raise_error(/invalid .* mode/)
      end
    end
  end

end
