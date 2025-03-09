# Force Rails to use the DATABASE_URL environment variable
if Rails.env.production? && ENV['DATABASE_URL']
  require 'uri'

  # Parse the DATABASE_URL
  uri = URI.parse(ENV['DATABASE_URL'])

  # Update the database configuration
  db_config = {
    adapter: 'postgresql',
    host: uri.host,
    username: uri.user,
    password: uri.password,
    port: uri.port || 5432,
    database: uri.path[1..-1],
    encoding: 'unicode',
    pool: ENV.fetch("RAILS_MAX_THREADS") { 5 }
  }

  # Set the connection configuration
  ActiveRecord::Base.establish_connection(db_config)
end
