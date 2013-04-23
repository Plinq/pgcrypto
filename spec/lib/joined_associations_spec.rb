require 'spec_helper'

describe 'Joined assocations' do
  before do
    keypath = File.expand_path(File.join(File.dirname(__FILE__), '..', 'support'))
    PGCrypto.keys[:private] = {:path => File.join(keypath, 'private.key')}
    PGCrypto.keys[:public] = {:path => File.join(keypath, 'public.key')}
  end

  it 'should not typecast to integer' do
    foo = Foo.create!(address: 'asdf')
    bar = foo.bars.create!
    Bar.joins(:foo).where(foos: { address: 'asdf' }).should include(bar)
  end
end
