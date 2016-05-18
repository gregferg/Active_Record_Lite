require_relative 'db_connection'
require_relative 'sql_object'

module Searchable
  def where(params)
    where_line = []

    params.each do |key, value|
      where_line << "#{key} = ?"
    end

    where_line = where_line.join(" AND ")
    results = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        "#{self.table_name}"
      WHERE
        #{where_line}
    SQL

    parse_all(results)
  end
end

class SQLObject
  extend Searchable
end
