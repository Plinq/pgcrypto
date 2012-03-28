require 'spec_helper'

describe PGCrypto do
  it "should extend ActiveRecord::Base" do
    PGCryptoTestModel.should respond_to(:pgcrypto)
  end

  describe "attributes" do
    before :each do
      PGCryptoTestModel.pgcrypto :test_column
    end

    it "should have readers and writers" do
      model = PGCryptoTestModel.new
      model.should respond_to(:test_column)
      model.should respond_to(:test_column=)
    end

    it "be settable on create" do
      model = PGCryptoTestModel.new(:test_column => 'this is a test')
      model.save!.should be_true
    end

    it "be settable on update" do
      model = PGCryptoTestModel.create!
      model.test_column = 'this is another test'
      model.save!.should be_true
    end

    it "be update-able" do
      model = PGCryptoTestModel.create!(:test_column => 'i am test column')
      model.update_attributes!(:test_column => 'but now i am a different column, son').should be_true
    end

    it "be retrievable at create" do
      model = PGCryptoTestModel.create!(:test_column => 'i am test column')
      model.test_column.should == 'i am test column'
    end

    it "be retrievable after create" do
      model = PGCryptoTestModel.create!(:test_column => 'i should return to you')
      PGCryptoTestModel.find(model.id).test_column.should == 'i should return to you'
    end

    it "be searchable" do
      model = PGCryptoTestModel.create!(:test_column => 'i am findable!')
      PGCryptoTestModel.where(:test_column => model.test_column).count.should == 1
    end
  end
end
