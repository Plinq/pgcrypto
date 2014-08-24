module PGCrypto
  class Railtie < Rails::Railtie
    generators do
      require 'pgcrypto/generators/install/install_generator'
      require 'pgcrypto/generators/upgrade/upgrade_generator'
    end

    rake_tasks do
      tasks = File.join(File.dirname(__FILE__), '../tasks/*.rake')
      Dir[tasks].each do |file|
        load file
      end
    end
  end
end
