# encoding: utf-8
require 'spec_helper'

describe CouchRest::Model::Property do

  before(:each) do
    reset_test_db!
    @card = Card.new(:first_name => "matt")
  end

  it "should be accessible from the object" do
    @card.properties.should be_an_instance_of(Array)
    @card.properties.map{|p| p.name}.should include("first_name")
  end

  it "should list object properties with values" do
    @card.properties_with_values.should be_an_instance_of(Hash)
    @card.properties_with_values["first_name"].should == "matt"
  end

  it "should let you access a property value (getter)" do
    @card.first_name.should == "matt"
  end

  it "should let you set a property value (setter)" do
    @card.last_name = "Aimonetti"
    @card.last_name.should == "Aimonetti"
  end

  it "should not let you set a property value if it's read only" do
    lambda{@card.read_only_value = "test"}.should raise_error
  end

  it "should let you use an alias for an attribute" do
    @card.last_name = "Aimonetti"
    @card.family_name.should == "Aimonetti"
    @card.family_name.should == @card.last_name
  end

  it "should let you use an alias for a casted attribute" do
    @card.cast_alias = Person.new(:name => ["Aimonetti"])
    @card.cast_alias.name.should == ["Aimonetti"]
    @card.calias.name.should == ["Aimonetti"]
    card = Card.new(:first_name => "matt", :cast_alias => {:name => ["Aimonetti"]})
    card.cast_alias.name.should == ["Aimonetti"]
    card.calias.name.should == ["Aimonetti"]
  end

  it "should raise error if property name coincides with model type key" do
    lambda { Cat.property(Cat.model_type_key) }.should raise_error(/already used/)
  end

  it "should not raise error if property name coincides with model type key on non-model" do
    lambda { Person.property(Article.model_type_key) }.should_not raise_error
  end

  it "should be auto timestamped" do
    @card.created_at.should be_nil
    @card.updated_at.should be_nil
    @card.save.should be_true
    @card.created_at.should_not be_nil
    @card.updated_at.should_not be_nil
  end

  describe "#as_couch_json" do

    it "should provide a simple hash from model" do
      @card.as_couch_json.class.should eql(Hash)
    end

    it "should remove properties from Hash if value is nil" do
      @card.last_name = nil
      @card.as_couch_json.keys.include?('last_name').should be_false
    end

  end

  describe "#as_json" do

    it "should provide a simple hash from model" do
      @card.as_json.class.should eql(Hash)
    end

    it "should pass options to Active Support's as_json" do
      @card.last_name = "Aimonetti"
      @card.as_json(:only => 'last_name').should eql('last_name' => 'Aimonetti')
    end

  end

  describe '#read_attribute' do
    it "should let you use read_attribute method" do
      @card.last_name = "Aimonetti"
      @card.read_attribute(:last_name).should eql('Aimonetti')
      @card.read_attribute('last_name').should eql('Aimonetti')
      last_name_prop = @card.properties.find{|p| p.name == 'last_name'}
      @card.read_attribute(last_name_prop).should eql('Aimonetti')
    end

    it 'should raise an error if the property does not exist' do
      expect { @card.read_attribute(:this_property_should_not_exist) }.to raise_error(ArgumentError)
    end
  end

  describe '#write_attribute' do
    it "should let you use write_attribute method" do
      @card.write_attribute(:last_name, 'Aimonetti 1')
      @card.last_name.should eql('Aimonetti 1')
      @card.write_attribute('last_name', 'Aimonetti 2')
      @card.last_name.should eql('Aimonetti 2')
      last_name_prop = @card.properties.find{|p| p.name == 'last_name'}
      @card.write_attribute(last_name_prop, 'Aimonetti 3')
      @card.last_name.should eql('Aimonetti 3')
    end

    it 'should raise an error if the property does not exist' do
      expect { @card.write_attribute(:this_property_should_not_exist, 823) }.to raise_error(ArgumentError)
    end


    it "should let you use write_attribute on readonly properties" do
      lambda {
        @card.read_only_value = "foo"
      }.should raise_error
      @card.write_attribute(:read_only_value, "foo")
      @card.read_only_value.should == 'foo'
    end

    it "should cast via write_attribute" do
      @card.write_attribute(:cast_alias, {:name => ["Sam", "Lown"]})
      @card.cast_alias.class.should eql(Person)
      @card.cast_alias.name.last.should eql("Lown")
    end

    it "should not cast via write_attribute if property not casted" do
      @card.write_attribute(:first_name, {:name => "Sam"})
      @card.first_name.class.should eql(Hash)
      @card.first_name[:name].should eql("Sam")
    end
  end

  describe "mass updating attributes without property" do
    
    describe "when mass_assign_any_attribute false" do
      
      it "should not allow them to be set" do
        @card.attributes = {:test => 'fooobar'}
        @card['test'].should be_nil
      end

     it 'should not allow them to be updated with update_attributes' do
       @card.update_attributes(:test => 'fooobar')
       @card['test'].should be_nil
     end

     it 'should not have a different revision after update_attributes' do
       @card.save
       rev = @card.rev
       @card.update_attributes(:test => 'fooobar')
       @card.rev.should eql(rev)
     end

     it 'should not have a different revision after save' do
       @card.save
       rev = @card.rev
       @card.attributes = {:test => 'fooobar'}
       @card.save
       @card.rev.should eql(rev)
     end

    end

    describe "when mass_assign_any_attribute true" do
      before(:each) do
        # dup Card class so that no other tests are effected
        card_class = Card.dup
        card_class.class_eval do
          mass_assign_any_attribute true
        end
        @card = card_class.new(:first_name => 'Sam')
      end

      it 'should allow them to be updated' do
        @card.attributes = {:testing => 'fooobar'}
        @card['testing'].should eql('fooobar')
      end

      it 'should allow them to be updated with update_attributes' do
        @card.update_attributes(:testing => 'fooobar')
        @card['testing'].should eql('fooobar')
      end

      it 'should have a different revision after update_attributes' do
        @card.save
        rev = @card.rev
        @card.update_attributes(:testing => 'fooobar')
        @card.rev.should_not eql(rev)
      end

      it 'should have a different revision after save' do
        @card.save
        rev = @card.rev
        @card.attributes = {:testing => 'fooobar'}
        @card.save
        @card.rev.should_not eql(rev)
      end

    end
  end

  describe "mass assignment protection" do

    it "should not store protected attribute using mass assignment" do
      cat_toy = CatToy.new(:name => "Zorro")
      cat = Cat.create(:name => "Helena", :toys => [cat_toy], :favorite_toy => cat_toy, :number => 1)
      cat.number.should be_nil
      cat.number = 1
      cat.save
      cat.number.should == 1
    end

    it "should not store protected attribute when 'declare accessible poperties, assume all the rest are protected'" do
      user = User.create(:name => "Marcos Tapajós", :admin => true)
      user.admin.should be_nil
    end

    it "should not store protected attribute when 'declare protected properties, assume all the rest are accessible'" do
      user = SpecialUser.create(:name => "Marcos Tapajós", :admin => true)
      user.admin.should be_nil
    end

  end

  describe "validation" do
    before(:each) do
      @invoice = Invoice.new(:client_name => "matt", :employee_name => "Chris", :location => "San Diego, CA")
    end

    it "should be able to be validated" do
      @card.valid?.should == true
    end

    it "should let you validate the presence of an attribute" do
      @card.first_name = nil
      @card.should_not be_valid
      @card.errors.should_not be_empty
      @card.errors[:first_name].should == ["can't be blank"]
    end

    it "should let you look up errors for a field by a string name" do
      @card.first_name = nil
      @card.should_not be_valid
      @card.errors['first_name'].should == ["can't be blank"]
    end

    it "should validate the presence of 2 attributes" do
      @invoice.clear
      @invoice.should_not be_valid
      @invoice.errors.should_not be_empty
      @invoice.errors[:client_name].should == ["can't be blank"]
      @invoice.errors[:employee_name].should_not be_empty
    end

    it "should let you set an error message" do
      @invoice.location = nil
      @invoice.valid?
      @invoice.errors[:location].should == ["Hey stupid!, you forgot the location"]
    end

    it "should validate before saving" do
      @invoice.location = nil
      @invoice.should_not be_valid
      @invoice.save.should be_false
      @invoice.should be_new
    end
  end

end

describe "properties of hash of casted models" do
  it "should be able to assign a casted hash to a hash property" do
    chain = KeyChain.new
    keys = {"House" => "8==$", "Office" => "<>==U"}
    chain.keys = keys
    chain.keys = chain.keys
    chain.keys.should == keys
  end
end

describe "properties of array of casted models" do

  before(:each) do
    @course = Course.new :title => 'Test Course'
  end

  it "should allow attribute to be set from an array of objects" do
    @course.questions = [Question.new(:q => "works?"), Question.new(:q => "Meaning of Life?")]
    @course.questions.length.should eql(2)
  end

  it "should allow attribute to be set from an array of hashes" do
    @course.questions = [{:q => "works?"}, {:q => "Meaning of Life?"}]
    @course.questions.length.should eql(2)
    @course.questions.last.q.should eql("Meaning of Life?")
    @course.questions.last.class.should eql(Question) # typecasting
  end

  it "should allow attribute to be set from hash with ordered keys and objects" do
    @course.questions = { '0' => Question.new(:q => "Test1"), '1' => Question.new(:q => 'Test2') }
    @course.questions.length.should eql(2)
    @course.questions.last.q.should eql('Test2')
    @course.questions.last.class.should eql(Question)
  end

  it "should allow attribute to be set from hash with ordered keys and sub-hashes" do
    @course.questions = { '10' => {:q => 'Test10'}, '0' => {:q => "Test1"}, '1' => {:q => 'Test2'} }
    @course.questions.length.should eql(3)
    @course.questions.last.q.should eql('Test10')
    @course.questions.last.class.should eql(Question)
  end

  it "should allow attribute to be set from hash with ordered keys and HashWithIndifferentAccess" do
    # This is similar to what you'd find in an HTML POST parameters
    hash = HashWithIndifferentAccess.new({ '0' => {:q => "Test1"}, '1' => {:q => 'Test2'} })
    @course.questions = hash
    @course.questions.length.should eql(2)
    @course.questions.last.q.should eql('Test2')
    @course.questions.last.class.should eql(Question)
  end


  it "should raise an error if attempting to set single value for array type" do
    lambda {
      @course.questions = Question.new(:q => 'test1')
    }.should raise_error(/Expecting an array/)
  end


end

describe "a casted model retrieved from the database" do
  before(:each) do
    reset_test_db!
    @cat = Cat.new(:name => 'Stimpy')
    @cat.favorite_toy = CatToy.new(:name => 'Stinky')
    @cat.toys << CatToy.new(:name => 'Feather')
    @cat.toys << CatToy.new(:name => 'Mouse')
    @cat.save
    @cat = Cat.get(@cat.id)
  end

  describe "as a casted property" do
    it "should already be casted_by its parent" do
      @cat.favorite_toy.casted_by.should === @cat
    end
  end

  describe "from a casted collection" do
    it "should already be casted_by its parent" do
      @cat.toys[0].casted_by.should === @cat
      @cat.toys[1].casted_by.should === @cat
    end
  end
end

describe "nested models (not casted)" do
  before(:each) do
    reset_test_db!
    @cat = ChildCat.new(:name => 'Stimpy')
    @cat.mother = {:name => 'Stinky'}
    @cat.siblings = [{:name => 'Feather'}, {:name => 'Felix'}]
    @cat.save
    @cat = ChildCat.get(@cat.id)
  end

  it "should correctly save single relation" do
    @cat.mother.name.should eql('Stinky')
    @cat.mother.casted_by.should eql(@cat)
  end

  it "should correctly save collection" do
    @cat.siblings.first.name.should eql("Feather")
    @cat.siblings.last.casted_by.should eql(@cat)
  end

end

describe "Property Class" do

  it "should provide name as string" do
    property = CouchRest::Model::Property.new(:test, String)
    property.name.should eql('test')
    property.to_s.should eql('test')
  end

  it "should provide class from type" do
    property = CouchRest::Model::Property.new(:test, String)
    property.type_class.should eql(String)
  end

  it "should provide base class from type in array" do
    property = CouchRest::Model::Property.new(:test, [String])
    property.type_class.should eql(String)
  end

  it "should raise error if type as string requested" do
    lambda {
      property = CouchRest::Model::Property.new(:test, 'String')
    }.should raise_error
  end

  it "should leave type nil and return class as nil also" do
    property = CouchRest::Model::Property.new(:test, nil)
    property.type.should be_nil
    property.type_class.should be_nil
  end

  it "should convert empty type array to [Object]" do
    property = CouchRest::Model::Property.new(:test, [])
    property.type_class.should eql(Object)
  end

  it "should set init method option or leave as 'new'" do
    # (bad example! Time already typecast)
    property = CouchRest::Model::Property.new(:test, Time)
    property.init_method.should eql('new')
    property = CouchRest::Model::Property.new(:test, Time, :init_method => 'parse')
    property.init_method.should eql('parse')
  end

  describe "#build" do
    it "should allow instantiation of new object" do
      property = CouchRest::Model::Property.new(:test, Date)
      obj = property.build(2011, 05, 21)
      obj.should eql(Date.new(2011, 05, 21))
    end
    it "should use init_method if provided" do
      property = CouchRest::Model::Property.new(:test, Date, :init_method => 'parse')
      obj = property.build("2011-05-21")
      obj.should eql(Date.new(2011, 05, 21))
    end
    it "should use init_method Proc if provided" do
      property = CouchRest::Model::Property.new(:test, Date, :init_method => Proc.new{|v| Date.parse(v)})
      obj = property.build("2011-05-21")
      obj.should eql(Date.new(2011, 05, 21))
    end
    it "should raise error if no class" do
      property = CouchRest::Model::Property.new(:test)
      lambda { property.build }.should raise_error(StandardError, /Cannot build/)
    end
  end

  ## Property Casting method. More thoroughly tested in typecast_spec.

  describe "casting" do
    it "should cast a value" do
      property = CouchRest::Model::Property.new(:test, Date)
      parent = mock("FooObject")
      property.cast(parent, "2010-06-16").should eql(Date.new(2010, 6, 16))
      property.cast_value(parent, "2010-06-16").should eql(Date.new(2010, 6, 16))
    end

    it "should cast an array of values" do
      property = CouchRest::Model::Property.new(:test, [Date])
      parent = mock("FooObject")
      property.cast(parent, ["2010-06-01", "2010-06-02"]).should eql([Date.new(2010, 6, 1), Date.new(2010, 6, 2)])
    end

    it "should set a CastedArray on array of Objects" do
      property = CouchRest::Model::Property.new(:test, [Object])
      parent = mock("FooObject")
      property.cast(parent, ["2010-06-01", "2010-06-02"]).class.should eql(CouchRest::Model::CastedArray)
    end

    it "should set a CastedArray on array of Strings" do
      property = CouchRest::Model::Property.new(:test, [String])
      parent = mock("FooObject")
      property.cast(parent, ["2010-06-01", "2010-06-02"]).class.should eql(CouchRest::Model::CastedArray)
    end

    it "should allow instantion of model via CastedArray#build" do
      property = CouchRest::Model::Property.new(:dates, [Date])
      parent = Article.new
      ary = property.cast(parent, [])
      obj = ary.build(2011, 05, 21)
      ary.length.should eql(1)
      ary.first.should eql(Date.new(2011, 05, 21))
      obj = ary.build(2011, 05, 22)
      ary.length.should eql(2)
      ary.last.should eql(Date.new(2011, 05, 22))
    end

    it "should cast an object that provides an array" do
      prop = Class.new do
        attr_accessor :ary
        def initialize(val); self.ary = val; end
        def as_json; ary; end
      end
      property = CouchRest::Model::Property.new(:test, prop)
      parent = mock("FooClass")
      cast = property.cast(parent, [1, 2])
      cast.ary.should eql([1, 2])
    end

    it "should set parent as casted_by object in CastedArray" do
      property = CouchRest::Model::Property.new(:test, [Object])
      parent = mock("FooObject")
      property.cast(parent, ["2010-06-01", "2010-06-02"]).casted_by.should eql(parent)
    end

    it "should set casted_by on new value" do
      property = CouchRest::Model::Property.new(:test, CatToy)
      parent = mock("CatObject")
      cast = property.cast(parent, {:name => 'catnip'})
      cast.casted_by.should eql(parent)
    end

  end

end

