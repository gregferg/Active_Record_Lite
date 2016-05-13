require_relative 'db_connection'
require 'active_support/inflector'

class SQLObject
  def self.columns
    if @columns.nil?

      column_names = DBConnection.execute2(<<-SQL)
        SELECT
          *
        FROM
          "#{table_name}"
      SQL

      @columns = column_names.first.map(&:to_sym)
    else
      @columns
    end
  end

  def self.finalize!
    columns.each do |column|
      define_method("#{column}") do
        attributes[column]
      end

      define_method("#{column}=") do |arg|
        attributes[column] = arg
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name.tableize
  end

  def self.table_name
      @table_name ||= self.name.tableize
  end

  def self.all
    rows = DBConnection.execute(<<-SQL)
      SELECT
        "#{table_name}".*
      FROM
        "#{table_name}"
    SQL
    parse_all(rows)
  end

  def self.parse_all(results)
    results.map { |hash| self.new(hash)}
  end

  def self.find(id)
    cat_info = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        "#{table_name}"
      WHERE
        id = '#{id}'
    SQL
    cat_info.empty? ? nil : self.new(cat_info.first)
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      sym = attr_name.to_sym

      if !self.class.columns.include?(sym)
        raise "unknown attribute '#{attr_name}'"
      end

      self.send("#{sym}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    @attributes.values
  end

  def insert
    col_names = self.class.columns[1..-1].join(", ")
    question_marks = []
    (self.class.columns.length - 1).times { question_marks << '?' }
    question_marks = question_marks.join(", ")
    vals = attribute_values
    DBConnection.execute(<<-SQL, *vals)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    p col_names = []
    self.class.columns[1..-1].map do |col|
      col_names << "#{col.to_s} = ?"
    end

    col_names = col_names.join(", ")
    p vals = attribute_values[1..-1]

    DBConnection.execute(<<-SQL, *vals, self.id)
    UPDATE
      #{self.class.table_name}
    SET
      #{col_names}
    WHERE
      id = ?
    SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end
