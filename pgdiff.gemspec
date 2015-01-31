# encoding: utf-8
Gem::Specification.new do |spec|
  spec.name        = 'pgdiff'
  spec.version     = '1.0.0'
  spec.homepage    = 'https://github.com/cfis/pgdiff.git'
  spec.description     = <<-EOS
Compares two PostgreSQL databases and generates the SQL statements needed to make their structure the same.
  EOS
  spec.summary     = <<-EOS
Provides a ruby script that compares two PostgreSQL databases and generates the SQL statements needed
to make their structure the same.  The original version was posted at
http://www.dzone.com/snippets/pgdiff-compare-two-postgresql.
EOS

  spec.authors = ['Charlie Savage']
  spec.platform = Gem::Platform::RUBY
  spec.files = Dir.glob(['CHANGELOG.rdoc',
                         'pgdiff.rb',
                         'bin/pgdiff.rb',
                         'Rakefile',
                         'README.rdoc',
                         'lib/*'])

  spec.executables << 'pgdiff'
  spec.required_ruby_version = '>= 1.9.3'
  spec.license = 'MIT'
  spec.date = Time.now
  spec.add_runtime_dependency('pg', ['>= 0.17.0'])
end
