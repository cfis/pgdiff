require_relative "../test_helper"

namespace :database do
  desc 'Create PgDiff test databases'
  task :create do
    # Create the databses
    connection = PG::Connection.new(PgDiff::CONNECTION_SPEC.merge(dbname: 'postgres'))
    [PgDiff::SOURCE_DATABASE, PgDiff::TARGET_DATABASE].each do |database_name|
      connection.exec("CREATE DATABASE #{database_name}")
    end

    # Setup the schemas
    [PgDiff::SOURCE_DATABASE, PgDiff::TARGET_DATABASE].each do |database_name|
      connection = PG::Connection.new(PgDiff::CONNECTION_SPEC.merge(dbname: database_name))
      sql_path = File.expand_path(File.join(__dir__, "#{database_name}.sql"))
      sql = File.read(sql_path)
      connection.exec(sql)
    end
  end

  desc 'Drop PgDiff test databases'
  task :drop do
    connection = PG::Connection.new(PgDiff::CONNECTION_SPEC.merge(dbname: 'postgres'))
    [PgDiff::SOURCE_DATABASE, PgDiff::TARGET_DATABASE].each do |database_name|
      connection.exec("DROP DATABASE IF EXISTS #{database_name}")
    end
  end

  desc 'Rebuild PgDiff test databases'
  task :rebuild => [:drop, :create]
end