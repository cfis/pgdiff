require 'yaml'

module PgDiff
  class ConnectionSpec
    def self.[](key)
      config[key.to_s]
    end

    private

    def self.config
      @config ||= begin
        # Find the file location
        path = File.expand_path('test/fixtures/databases.yaml')
        YAML.load_file(path)
      end
    end
  end
end
