require_relative "../test_helper"

namespace :database do
  desc 'Create PgDiff test databases'
  task :create do
    # Create the databases
    postgres_connection = PG::Connection.new(PgDiff::ConnectionSpec.source.merge(dbname: 'postgres'))
    [PgDiff::ConnectionSpec.source['dbname'], PgDiff::ConnectionSpec.target['dbname']].each do |database_name|
      postgres_connection.exec("CREATE DATABASE #{database_name}")
    end

    # Setup the schemas
    [PgDiff::ConnectionSpec.source, PgDiff::ConnectionSpec.target].each do |connection_spec|
      connection = PG::Connection.new(connection_spec)
      sql_path = File.expand_path(File.join(__dir__, "#{connection_spec['dbname']}.sql"))
      sql = File.read(sql_path)
      connection.exec(sql)
    end
  end

  desc 'Drop PgDiff test databases'
  task :drop do
    postgres_connection = PG::Connection.new(PgDiff::ConnectionSpec.source.merge(dbname: 'postgres'))
    [PgDiff::ConnectionSpec.source['dbname'], PgDiff::ConnectionSpec.target['dbname']].each do |database_name|
      postgres_connection.exec("DROP DATABASE IF EXISTS #{database_name} WITH (force)")
    end
  end

  desc 'Rebuild PgDiff test databases'
  task :rebuild => [:drop, :create]
end