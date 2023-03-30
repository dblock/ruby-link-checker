require 'benchmark'
require 'net/http'
require 'ruby-link-checker'

input = File.readlines(File.join(__dir__, 'data/opensearch.org/links.txt')).map(&:strip)

Benchmark.bm do |benchmark|
  benchmark.report('LinkChecker::Net::HTTP::Checker') do
    checker = LinkChecker::Net::HTTP::Checker.new
    checker.logger.level = Logger::INFO
    input.each do |url|
      checker.check! url
    end
  end
end
