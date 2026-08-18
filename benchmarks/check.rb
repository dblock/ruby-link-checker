require 'benchmark'
require 'net/http'
require 'typhoeus'
require 'async'
require 'async/http'
require 'ruby-link-checker'

input = File.readlines(File.join(__dir__, 'data/opensearch.org/small.txt')).map(&:strip)

CHECKERS = [
  # LinkChecker::Net::HTTP::Checker,
  LinkChecker::Typhoeus::Hydra::Checker,
  LinkChecker::Async::HTTP::Checker
].freeze

Benchmark.bm(40) do |benchmark|
  CHECKERS.each do |checker_klass|
    benchmark.report(checker_klass.name) do
      checker = checker_klass.new
      checker.logger.level = Logger::INFO
      case checker
      when LinkChecker::Typhoeus::Hydra::Checker
        checker.timeout = 5 # 1/12th of the default 60s
        checker.connecttimeout = 1 # 1/10th of the default 10s
      else
        checker.read_timeout = 5 # 1/12th of the default 60s
        checker.open_timeout = 5 # 1/12th of the default 60s
      end
      input.each do |url|
        checker.check url
      end
      checker.run if checker.respond_to?(:run)
      checker.results.each_pair do |bucket, results|
        puts "#{bucket}: #{results.size}"
      end
    end
  end
end
