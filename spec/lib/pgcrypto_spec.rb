require 'spec_helper'

# require 'logger'
# ActiveRecord::Base.logger = Logger.new(STDOUT)

specs = proc do

  let(:stored_raw) {
    connection = PGCryptoTestModel.connection
    result = connection.select_one("SELECT encrypted_text FROM pgcrypto_test_models LIMIT 1")
    result['encrypted_text']
  }

  # Default test text
  let(:text) { "text to encrypt" }
  # That text as it appears un-encrypted in a binary column - we'll compare
  # this to what gets set to ensure the text is properly encrypted
  let(:text_raw) { "\\x7465787420746f20656e6372797074" }

  let(:text_2) { "something else entirely" }
  let(:text_2_raw) { "\\x736f6d657468696e6720656c736520656e746972656c79" }

  it "extends ActiveRecord::Base" do
    expect(PGCryptoTestModel).to respond_to(:has_encrypted_column)
    expect(PGCryptoTestModel).to respond_to(:pgcrypto)
  end

  it "encrypts text on insert" do
    PGCryptoTestModel.create!(name: 'foobar', encrypted_text: text)
    expect(stored_raw).not_to eq(text_raw)
    expect(PGCryptoTestModel.last.name).to eq('foobar')
  end

  it "encrypts new text on update" do
    PGCryptoTestModel.create.tap do |model|
      model.encrypted_text = text
      model.save!
    end
    expect(stored_raw).not_to eq(text_raw)
  end

  it "encrypts changed text on update" do
    PGCryptoTestModel.create!(encrypted_text: text).tap do |model|
      model.update_attributes!(encrypted_text: text_2)
    end
    expect(stored_raw).not_to eq(text_2_raw)
  end

  it "keeps plaintext versions of the encrypted text" do
    model = PGCryptoTestModel.create!(encrypted_text: text)
    expect(model.encrypted_text).to eq(text)
  end

  it "decrypts text when it is selected" do
    model = PGCryptoTestModel.create!(encrypted_text: text)
    expect(PGCryptoTestModel.find(model.id).encrypted_text).to eq(text)
  end

  it "retrieves decrypted text after update" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'i will update')
    expect(PGCryptoTestModel.find(model.id).encrypted_text).to eq('i will update')
    model.update_attributes!(encrypted_text: 'i updated', name: 'testy mctesterson')
    expect(PGCryptoTestModel.find(model.id).encrypted_text).to eq('i updated')
  end

  it "retrieves decrypted text without update" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'i will update')
    expect(PGCryptoTestModel.find(model.id).encrypted_text).to eq('i will update')
    model.encrypted_text = 'i updated'
    expect(model.encrypted_text).to eq('i updated')
  end

  it "supports querying encrypted columns transparently" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'i am findable!')
    expect(PGCryptoTestModel.where(encrypted_text: model.encrypted_text)).to eq([model])
  end

  it "tracks changes" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'i am clean')
    model.encrypted_text = "now i'm not!"
    expect(model.encrypted_text_changed?).to be_truthy
  end

  it "is not dirty if attributes are unchanged" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'i am clean')
    model.encrypted_text = 'i am clean'
    expect(model.encrypted_text_changed?).not_to be_truthy
  end

  it "reloads with the class" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'i am clean')
    model.encrypted_text = 'i am dirty'
    model.reload
    expect(model.encrypted_text).to eq('i am clean')
    expect(model.encrypted_text_changed?).not_to be_truthy
  end

  it "decrypts direct selects" do
    model = PGCryptoTestModel.create!(:encrypted_text => 'to be selected...')
    expect(PGCryptoTestModel.select([:id, :encrypted_text]).where(id: model.id).first).to eq(model)
  end
end

keypath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'support'))
describe PGCrypto do
  describe "without password-protected keys" do
    before :all do
      PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.key')}
      PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.key')}
    end

     instance_eval(&specs)
  end

  describe "with password-protected keys" do
    before :each do
      PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.password.key'), :password => 'password'}
      PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.password.key')}
    end

    instance_eval(&specs)
  end

  describe "with the PostGIS adapter" do
    before :all do
      require 'activerecord-postgis-adapter'
      PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.key')}
      PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.key')}
      PGCrypto.base_adapter = ActiveRecord::ConnectionAdapters::PostGISAdapter::MainAdapter
    end

    instance_eval(&specs)
  end
end
