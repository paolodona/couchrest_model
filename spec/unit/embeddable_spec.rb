# encoding: utf-8
require "spec_helper"

class WithCastedModelMixin
  include CouchRest::Model::Embeddable
  property :name
  property :no_value
  property :details, Object, :default => {}
  property :casted_attribute, WithCastedModelMixin
end

class OldFashionedMixin < Hash
  include CouchRest::Model::CastedModel
  property :name
end

class DummyModel < CouchRest::Model::Base
  use_database TEST_SERVER.default_database
  raise "Default DB not set" if TEST_SERVER.default_database.nil?
  property :casted_attribute, WithCastedModelMixin
  property :keywords,         [String]
  property :old_casted_attribute, OldFashionedMixin
  property :sub_models do |child|
    child.property :title
  end
  property :param_free_sub_models do
    property :title
  end
end

class WithCastedCallBackModel
  include CouchRest::Model::Embeddable
  property :name
  property :run_before_validation
  property :run_after_validation

  validates_presence_of :run_before_validation

  before_validation do |object|
    object.run_before_validation = true
  end
  after_validation do |object|
    object.run_after_validation = true
  end
end

class CastedCallbackDoc < CouchRest::Model::Base
  use_database TEST_SERVER.default_database
  raise "Default DB not set" if TEST_SERVER.default_database.nil?
  property :callback_model, WithCastedCallBackModel
end

describe CouchRest::Model::Embeddable do

  describe "isolated" do
    before(:each) do
      @obj = WithCastedModelMixin.new
    end
    it "should automatically include the property mixin and define getters and setters" do
      @obj.name = 'Matt'
      @obj.name.should == 'Matt'
    end

    it "should allow override of default" do
      @obj = WithCastedModelMixin.new(:name => 'Eric', :details => {'color' => 'orange'})
      @obj.name.should == 'Eric'
      @obj.details['color'].should == 'orange'
    end
    it "should always return base_doc? as false" do
      @obj.base_doc?.should be_false
    end
    it "should call after_initialize callback if available" do
      klass = Class.new do
        include CouchRest::Model::CastedModel
        after_initialize :set_name
        property :name
        def set_name; self.name = "foobar"; end
      end
      @obj = klass.new
      @obj.name.should eql("foobar")
    end
    it "should allow override of initialize with super" do
      klass = Class.new do
        include CouchRest::Model::Embeddable
        after_initialize :set_name
        property :name
        def set_name; self.name = "foobar"; end
        def initialize(attrs = {}); super(); end
      end
      @obj = klass.new
      @obj.name.should eql("foobar")
    end
  end

  describe "casted as an attribute, but without a value" do
    before(:each) do
      @obj = DummyModel.new
      @casted_obj = @obj.casted_attribute
    end
    it "should be nil" do
      @casted_obj.should == nil
    end
  end

  describe "anonymous sub casted models" do
    before :each do
      @obj = DummyModel.new
    end
    it "should be empty initially" do
      @obj.sub_models.should_not be_nil
      @obj.sub_models.should be_empty
    end
    it "should be updatable using a hash" do
      @obj.sub_models << {:title => 'test'}
      @obj.sub_models.first.title.should eql('test')
    end
    it "should be empty intitally (without params)" do
      @obj.param_free_sub_models.should_not be_nil
      @obj.param_free_sub_models.should be_empty
    end
    it "should be updatable using a hash (without params)" do
      @obj.param_free_sub_models << {:title => 'test'}
      @obj.param_free_sub_models.first.title.should eql('test')
    end
  end

  describe "casted as attribute" do
    before(:each) do
      casted = {:name => 'not whatever'}
      @obj = DummyModel.new(:casted_attribute => {:name => 'whatever', :casted_attribute => casted})
      @casted_obj = @obj.casted_attribute
    end

    it "should be available from its parent" do
      @casted_obj.should be_an_instance_of(WithCastedModelMixin)
    end

    it "should have the getters defined" do
      @casted_obj.name.should == 'whatever'
    end

    it "should know who casted it" do
      @casted_obj.casted_by.should == @obj
    end

    it "should know which property casted it" do
      @casted_obj.casted_by_property.should == @obj.properties.detect{|p| p.to_s == 'casted_attribute'}
    end

    it "should return nil for the 'no_value' attribute" do
      @casted_obj.no_value.should be_nil
    end

    it "should return nil for the unknown attribute" do
      @casted_obj["unknown"].should be_nil
    end

    it "should return {} for the hash attribute" do
      @casted_obj.details.should == {}
    end

    it "should cast its own attributes" do
      @casted_obj.casted_attribute.should be_instance_of(WithCastedModelMixin)
    end

    it "should raise an error if save or update_attributes called" do
      expect { @casted_obj.casted_attribute.save }.to raise_error(NoMethodError)
      expect { @casted_obj.casted_attribute.update_attributes(:name => "Fubar") }.to raise_error(NoMethodError)
    end
  end

  # Basic testing for an old fashioned casted hash
  describe "old hash casted as attribute" do
    before :each do
      @obj = DummyModel.new(:old_casted_attribute => {:name => 'Testing'})
      @casted_obj = @obj.old_casted_attribute
    end
    it "should be available from its parent" do
      @casted_obj.should be_an_instance_of(OldFashionedMixin)
    end

    it "should have the getters defined" do
      @casted_obj.name.should == 'Testing'
    end

    it "should know who casted it" do
      @casted_obj.casted_by.should == @obj
    end

    it "should know which property casted it" do
      @casted_obj.casted_by_property.should == @obj.properties.detect{|p| p.to_s == 'old_casted_attribute'}
    end

    it "should return nil for the unknown attribute" do
      @casted_obj["unknown"].should be_nil
    end
  end

  describe "casted as an array of a different type" do
    before(:each) do
      @obj = DummyModel.new(:keywords => ['couch', 'sofa', 'relax', 'canapé'])
    end

    it "should cast the array properly" do
      @obj.keywords.should be_kind_of(Array)
      @obj.keywords.first.should == 'couch'
    end
  end

  describe "update attributes without saving" do
    before(:each) do
      @question = Question.new(:q => "What is your quest?", :a => "To seek the Holy Grail")
    end
    it "should work for attribute= methods" do
      @question.q.should == "What is your quest?"
      @question['a'].should == "To seek the Holy Grail"
      @question.update_attributes_without_saving(:q => "What is your favorite color?", 'a' => "Blue")
      @question['q'].should == "What is your favorite color?"
      @question.a.should == "Blue"
    end

    it "should also work for attributes= alias" do
      @question.respond_to?(:attributes=).should be_true
      @question.attributes = {:q => "What is your favorite color?", 'a' => "Blue"}
      @question['q'].should == "What is your favorite color?"
      @question.a.should == "Blue"
    end

    it "should flip out if an attribute= method is missing" do
      lambda {
        @q.update_attributes_without_saving('foo' => "something", :a => "No green")
      }.should raise_error(NoMethodError)
    end

    it "should not change any attributes if there is an error" do
      lambda {
        @q.update_attributes_without_saving('foo' => "something", :a => "No green")
      }.should raise_error(NoMethodError)
      @question.q.should == "What is your quest?"
      @question.a.should == "To seek the Holy Grail"
    end

  end

  describe "saved document with casted models" do
    before(:each) do
      reset_test_db!
      @obj = DummyModel.new(:casted_attribute => {:name => 'whatever'})
      @obj.save.should be_true
      @obj = DummyModel.get(@obj.id)
    end

    it "should be able to load with the casted models" do
      casted_obj = @obj.casted_attribute
      casted_obj.should_not be_nil
      casted_obj.should be_an_instance_of(WithCastedModelMixin)
    end

    it "should have defined getters for the casted model" do
      casted_obj = @obj.casted_attribute
      casted_obj.name.should == "whatever"
    end

    it "should have defined setters for the casted model" do
      casted_obj = @obj.casted_attribute
      casted_obj.name = "test"
      casted_obj.name.should == "test"
    end

    it "should retain an override of a casted model attribute's default" do
      casted_obj = @obj.casted_attribute
      casted_obj.details['color'] = 'orange'
      @obj.save
      casted_obj = DummyModel.get(@obj.id).casted_attribute
      casted_obj.details['color'].should == 'orange'
    end

  end

  describe "saving document with array of casted models and validation" do
    before :each do
      @cat = Cat.new :name => "felix"
      @cat.save
    end

    it "should save" do
      toy = CatToy.new :name => "Mouse"
      @cat.toys.push(toy)
      @cat.save.should be_true
      @cat = Cat.get @cat.id
      @cat.toys.class.should == CouchRest::Model::CastedArray
      @cat.toys.first.class.should == CatToy
      @cat.toys.first.should === toy
    end

    it "should fail because name is not present" do
      toy = CatToy.new
      @cat.toys.push(toy)
      @cat.should_not be_valid
      @cat.save.should be_false
    end

    it "should not fail if the casted model doesn't have validation" do
      Cat.property :masters, [Person], :default => []
      Cat.validates_presence_of :name
      cat = Cat.new(:name => 'kitty')
      cat.should be_valid
      cat.masters.push Person.new
      cat.should be_valid
    end
  end

  describe "calling valid?" do
    before :each do
      @cat = Cat.new
      @toy1 = CatToy.new
      @toy2 = CatToy.new
      @toy3 = CatToy.new
      @cat.favorite_toy = @toy1
      @cat.toys << @toy2
      @cat.toys << @toy3
    end

    describe "on the top document" do
      it "should put errors on all invalid casted models" do
        @cat.should_not be_valid
        @cat.errors.should_not be_empty
        @toy1.errors.should_not be_empty
        @toy2.errors.should_not be_empty
        @toy3.errors.should_not be_empty
      end

      it "should not put errors on valid casted models" do
        @toy1.name = "Feather"
        @toy2.name = "Twine"
        @cat.should_not be_valid
        @cat.errors.should_not be_empty
        @toy1.errors.should be_empty
        @toy2.errors.should be_empty
        @toy3.errors.should_not be_empty
      end

      it "should not use dperecated ActiveModel options" do
        ActiveSupport::Deprecation.should_not_receive(:warn)
        @cat.should_not be_valid
      end
    end

    describe "on a casted model property" do
      it "should only validate itself" do
        @toy1.should_not be_valid
        @toy1.errors.should_not be_empty
        @cat.errors.should be_empty
        @toy2.errors.should be_empty
        @toy3.errors.should be_empty
      end
    end

    describe "on a casted model inside a casted collection" do
      it "should only validate itself" do
        @toy2.should_not be_valid
        @toy2.errors.should_not be_empty
        @cat.errors.should be_empty
        @toy1.errors.should be_empty
        @toy3.errors.should be_empty
      end
    end
  end

  describe "calling new? on a casted model" do
    before :each do
      reset_test_db!
      @cat = Cat.new(:name => 'Sockington')
      @favorite_toy = CatToy.new(:name => 'Catnip Ball')
      @cat.favorite_toy = @favorite_toy
      @cat.toys << CatToy.new(:name => 'Fuzzy Stick')
    end

    it "should be true on new" do
      CatToy.new.should be_new
      CatToy.new.new_record?.should be_true
    end

    it "should be true after assignment" do
      @cat.should be_new
      @cat.favorite_toy.should be_new
      @cat.toys.first.should be_new
    end

    it "should not be true after create or save" do
      @cat.create
      @cat.save
      @cat.favorite_toy.should_not be_new
      @cat.toys.first.casted_by.should eql(@cat)
      @cat.toys.first.should_not be_new
    end

    it "should not be true after get from the database" do
      @cat.save
      @cat = Cat.get(@cat.id)
      @cat.favorite_toy.should_not be_new
      @cat.toys.first.should_not be_new
    end

    it "should still be true after a failed create or save" do
      @cat.name = nil
      @cat.create.should be_false
      @cat.save.should be_false
      @cat.favorite_toy.should be_new
      @cat.toys.first.should be_new
    end
  end

  describe "calling base_doc from a nested casted model" do
    before :each do
      @course = Course.new(:title => 'Science 101')
      @professor = Person.new(:name => ['Professor', 'Plum'])
      @cat = Cat.new(:name => 'Scratchy')
      @toy1 = CatToy.new
      @toy2 = CatToy.new
      @course.professor = @professor
      @professor.pet = @cat
      @cat.favorite_toy = @toy1
      @cat.toys << @toy2
    end

    it 'should let you copy over casted arrays' do
      question = Question.new
      @course.questions << question
      new_course = Course.new
      new_course.questions = @course.questions
      new_course.questions.should include(question)
    end

    it "should reference the top document for" do
      @course.base_doc.should === @course
      @professor.casted_by.should === @course
      @professor.base_doc.should === @course
      @cat.base_doc.should === @course
      @toy1.base_doc.should === @course
      @toy2.base_doc.should === @course
    end

    it "should call setter on top document" do
      @toy1.base_doc.should_not be_nil
      @toy1.base_doc.title = 'Tom Foolery'
      @course.title.should == 'Tom Foolery'
    end

    it "should return nil if not yet casted" do
      person = Person.new
      person.base_doc.should == nil
    end
  end

  describe "calling base_doc.save from a nested casted model" do
    before :each do
      reset_test_db!
      @cat = Cat.new(:name => 'Snowball')
      @toy = CatToy.new
      @cat.favorite_toy = @toy
    end

    it "should not save parent document when casted model is invalid" do
      @toy.should_not be_valid
      @toy.base_doc.save.should be_false
      lambda{@toy.base_doc.save!}.should raise_error
    end

    it "should save parent document when nested casted model is valid" do
      @toy.name = "Mr Squeaks"
      @toy.should be_valid
      @toy.base_doc.save.should be_true
      lambda{@toy.base_doc.save!}.should_not raise_error
    end
  end

  describe "callbacks" do
    before(:each) do
      @doc = CastedCallbackDoc.new
      @model = WithCastedCallBackModel.new
      @doc.callback_model = @model
    end

    describe "validate" do
      it "should run before_validation before validating" do
        @model.run_before_validation.should be_nil
        @model.should be_valid
        @model.run_before_validation.should be_true
      end
      it "should run after_validation after validating" do
        @model.run_after_validation.should be_nil
        @model.should be_valid
        @model.run_after_validation.should be_true
      end
    end
  end
end
