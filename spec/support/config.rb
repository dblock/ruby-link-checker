RSpec.configure do |config|
    config.after do
        LinkChecker::Config.reset
    end
  end
