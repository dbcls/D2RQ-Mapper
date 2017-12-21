require 'sqlite3'

module TogoMapper
class DB
class SQLite < TogoMapper::DB::Common

  include SQLite3

  def initialize(connection_config)
    @client = Database.new(connection_config[:database])
  end


  def tables
    query = "SELECT tbl_name FROM sqlite_master WHERE type == 'table'"
    @client.execute(query).flatten
  end


  def columns(table)
    if table.blank?
      []
    else
      @client.table_info(table).map{ |h| h['name'] }
    end
  end


  def records(table, offset = 0, limit = 5)
    query = sql_for_fetch_example_records(table, offset, limit)
    puts "#{'=' * 80}\n#{query}"
    
    rows = []
    results = @client.execute2(query)
    col_names = results.shift
    results.each do |row|
      h = {}
      col_names.zip(row).each do |ary|
        h[ary[0]] = ary[1]
      end
      rows << h
    end

    rows
  end


  def pk_info(database, table)
    info = {}
    info[:column_name] = ''

    @client.table_info(table) do |row|
      if row['pk'] == 1
        info[:column_name] = row['name']
        break
      end
    end
    
    info
  end
  
  
  def close
    @client.close
  end

  
  def escape(s)
    s.gsub( /"/, %Q|\"| )
  end

end
end
end

if __FILE__ == $0
  require 'pp'
  connection_config = { database: '/home/d2rq/test/sqlite/iswc-full5.db' }
  sqlite = TogoMapper::DB::SQLite.new(connection_config)
  tables =  sqlite.tables
  pp tables
  tables.each do |table|
    columns = sqlite.columns(table)
    pp columns

    records = sqlite.records(table)
    pp records
  end
  sqlite.close
end
