require 'benchmark'
require 'net/http'
require 'typhoeus'
require 'ruby-link-checker'

input = File.readlines(File.join(__dir__, 'data/opensearch.org/small.txt')).map(&:strip)

Benchmark.bm do |benchmark|
  # benchmark.report('LinkChecker::Net::HTTP::Checker') do
  #   checker = LinkChecker::Net::HTTP::Checker.new
  #   checker.logger.level = Logger::INFO
  #   input.each do |url|
  #     checker.check! url
  #   end
  #   checker.results.each_pair do |bucket, results|
  #     puts "#{bucket}: #{results.size}"
  #   end
  # end

  benchmark.report('LinkChecker::Typhoeus::Hydra::Checker') do
    checker = LinkChecker::Typhoeus::Hydra::Checker.new(
      hydra: {
        max_concurrency: 3
      }
    )
    checker.logger.level = Logger::INFO
    input.each do |url|
      checker.check! url
    end
    checker.hydra.run
    checker.results.each_pair do |bucket, results|
      puts "#{bucket}: #{results.size}"
    end
  end
end
