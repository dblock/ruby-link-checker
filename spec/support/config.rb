RSpec.configure do |config|
  config.before do
    LinkChecker::Logger.default.level = Logger::DEBUG
  end
  config.after do
    LinkChecker::Config.reset
  end
end
