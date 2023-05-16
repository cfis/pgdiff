module PgDiff
  class Sequence
    def initialize(conn, sch, relname)
       @name = "#{sch}.#{relname}"
    end

    def definition
      "CREATE SEQUENCE #{@name} ;"
    end
  end
end