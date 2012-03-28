require 'autotest/fsevent'
require 'autotest/growl'

Autotest.add_discovery { "rspec2" }

Autotest.add_hook :initialize do |autotest|
  autotest.add_mapping %r(^lib/**/*\.rb$) do |file, _|
    Dir['spec/**/*.rb']
  end

  autotest.add_mapping %r(^spec/support/*\.rb$) do |file, _|
    Dir['spec/**/*.rb']
  end
end
