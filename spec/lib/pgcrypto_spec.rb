require 'spec_helper'

# require 'logger'
# ActiveRecord::Base.logger = Logger.new(STDOUT)

specs = proc do
  it "should extend ActiveRecord::Base" do
    PGCryptoTestModel.should respond_to(:pgcrypto)
  end

  it "should have readers and writers" do
    model = PGCryptoTestModel.new
    model.should respond_to(:test_column)
    model.should respond_to(:test_column=)
  end

  it "should be settable on create" do
    model = PGCryptoTestModel.new(:test_column => 'this is a test')
    model.save!.should be_true
  end

  it "should be settable on update" do
    model = PGCryptoTestModel.create!
    model.test_column = 'this is another test'
    model.save!.should be_true
  end

  it "should be update-able" do
    model = PGCryptoTestModel.create!(:test_column => 'i am test column')
    model.update_attributes!(:test_column => 'but now i am a different column, son').should be_true
    model.test_column.should == 'but now i am a different column, son'
  end

  it "should be retrievable at create" do
    model = PGCryptoTestModel.create!(:test_column => 'i am test column')
    model.test_column.should == 'i am test column'
  end

  it "should be retrievable after create" do
    model = PGCryptoTestModel.create!(:test_column => 'i should return to you')
    PGCryptoTestModel.find(model.id).test_column.should == 'i should return to you'
  end

  it "should be retrievable at update" do
    model = PGCryptoTestModel.create!(:test_column => 'i will update')
    model.test_column.should == 'i will update'
    model.update_attributes!(:test_column => 'i updated')
    model.test_column.should == 'i updated'
  end

  it "should be retrievable without update" do
    model = PGCryptoTestModel.create!(:test_column => 'i will update')
    model.test_column.should == 'i will update'
    model.test_column = 'i updated'
    model.test_column.should == 'i updated'
  end

  it "should be searchable" do
    model = PGCryptoTestModel.create!(:test_column => 'i am findable!')
    PGCryptoTestModel.where(:test_column => model.test_column).should == [model]
  end

  it "should track changes" do
    model = PGCryptoTestModel.create!(:test_column => 'i am clean')
    model.test_column = "now i'm not!"
    model.test_column_changed?.should be_true
  end

  it "should not be dirty if unchanged" do
    model = PGCryptoTestModel.create!(:test_column => 'i am clean')
    model.test_column = 'i am clean'
    model.test_column_changed?.should_not be_true
  end

  it "should reload with the class" do
    model = PGCryptoTestModel.create!(:test_column => 'i am clean')
    model.test_column = 'i am dirty'
    model.reload
    model.test_column.should == 'i am clean'
    model.test_column_changed?.should_not be_true
  end

  it "should allow direct setting of values as well" do
    model = PGCryptoTestModel.create!(:test_column => 'one')
    model.test_column.should == 'one'
    model.test_column = 'two'
    model.save!.should be_true
    model.select_pgcrypto_column(:test_column).value.should == 'two'
  end

  it "should delete the column when I set the value to nil" do
    model = PGCryptoTestModel.create!(:test_column => 'one')
    model.test_column = nil
    model.save!
    model.select_pgcrypto_column(:test_column).should be_nil
  end

  it "should plz work" do
    model = PGCryptoTestModel.find(PGCryptoTestModel.create!(:test_column => 'one'))
    model.test_column = 'two'
    model.save!
    model.select_pgcrypto_column(:test_column).value.should == 'two'
  end
end

keypath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'support'))
describe PGCrypto do
  describe "without password-protected keys" do
    before :all do
      PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.key')}
      PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.key')}
    end

    # instance_eval(&specs)
  end

  describe "with password-protected keys" do
    before :each do
      PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.password.key'), :password => 'password'}
      PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.password.key')}
    end

    instance_eval(&specs)
  end

  describe "with Brett's keys" do
    before :each do
      PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.brett.key'), :password => '4a13zhUF'}
      PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.brett.key')}
    end

    instance_eval(&specs)
  end
end
