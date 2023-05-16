module PgDiff
  class View
    attr_reader :def, :name

    def initialize(conn, sch, relname)
      @name = "#{sch}.#{relname}"
      view_qery = <<~EOT
        SELECT pg_catalog.pg_get_viewdef('#{@name}'::regclass, true)
      EOT
      tuple = conn.query(view_qery).first
      @def = tuple['pg_get_viewdef']
    end

    def definition
      "CREATE VIEW #{@name} AS #{@def}"
    end
  end
end