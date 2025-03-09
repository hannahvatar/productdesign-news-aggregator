# Debug scraper classes
puts "Loading scrapers from: #{Rails.root.join('lib', 'scrapers')}"

Dir[Rails.root.join('lib', 'scrapers', '*.rb')].each do |file|
  puts "Loading scraper file: #{file}"
  require file
end

# Check what scraper classes are actually loaded
ObjectSpace.each_object(Class).select { |klass|
  klass.name&.start_with?('Scrapers::')
}.each do |klass|
  puts "Found scraper class: #{klass.name}"
end
