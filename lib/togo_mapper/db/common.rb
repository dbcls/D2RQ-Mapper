module TogoMapper
class DB
class Common

  def sql_for_fetch_example_records(table, offset = 0, limit = 5)
    if table.is_a?(String)
      # Table, View
      query = "SELECT * FROM #{quoted_table_name(table)}"
    elsif table.is_a?(Hash)
      # Joined table
      if table.key?(:inter)
        # m:n join
        query =
          sql_for_many2many_join(table[:main][:table_name], table[:main][:key_name], table[:main][:column_names],
                                 table[:join][:table_name], table[:join][:key_name], table[:join][:column_names],
                                 table[:inter][:table_name], table[:inter][:l_key_name], table[:inter][:r_key_name])
      else
        # 1:n join
        query =
          sql_for_one2many_join(table[:main][:table_name], table[:main][:key_name], table[:main][:column_names],
                                table[:join][:table_name], table[:join][:key_name], table[:join][:column_names])
      end
    end

    "#{query} #{offset_limit_phase(offset, limit)}"
  end


  def query_for_one_table(table_name, where_phrase = nil)
    query = "SELECT #{columns(table_name).map{ |column_name| quoted_column_name(table_name, column_name)}.join(',')} FROM #{quoted_table_name(table_name)}"

    if where_phrase.blank?
      query
    else
      "#{query} WHERE #{where_phrase}"
    end
  end


  def sql_for_one2many_join(table1, key1, columns1, table2, key2, columns2)
    main_cols = columns_for_select_phrase(table1, columns1)
    join_cols = columns_for_select_phrase(table2, columns2)
    
    "SELECT #{main_cols},#{join_cols} FROM #{quoted_table_name(table1)},#{quoted_table_name(table2)} WHERE #{quoted_column_name(table1, key1)} = #{quoted_column_name(table2, key2)}"
  end


  def sql_for_many2many_join(table1, key1, columns1, table2, key2, columns2, inter_table, inter_key1, inter_key2)
    main_cols = columns_for_select_phrase(table1, columns1)
    join_cols = columns_for_select_phrase(table2, columns2)
    
    "SELECT #{main_cols},#{join_cols} FROM #{quoted_table_name(table1)},#{quoted_table_name(inter_table)},#{quoted_table_name(table2)} WHERE #{quoted_column_name(table1, key1)} = #{quoted_column_name(inter_table, inter_key1)} AND #{quoted_column_name(inter_table, inter_key2)} = #{quoted_column_name(table2, key2)}"
  end
  

  def columns_for_select_phrase(table, columns)
    columns.map{ |col_name| "#{quoted_column_name(table, col_name)} #{column_alias_for_sql(table, col_name)}" }.join(',')
  end

  
  def offset_limit_phase(offset = 0, limit = 5)
    if offset == 0
      "LIMIT #{limit}"
    else
      "LIMIT #{offset}, #{limit}"
    end
  end

  
  def quoted_table_name(table_name)
    "#{identifier_quotation_char}#{table_name}#{identifier_quotation_char}"
  end


  def quoted_column_name(table_name, column_name)
    quoted_name = "#{identifier_quotation_char}#{column_name}#{identifier_quotation_char}"
    unless table_name.to_s.empty?
      quoted_name = "#{quoted_table_name(table_name)}.#{quoted_name}"
    end
    
    quoted_name
  end
  
  
  def identifier_quotation_char
    %Q|"|
  end


  def column_alias_for_sql(table_name, column_name)
    "#{identifier_quotation_char}#{escape(table_name)}.#{escape(column_name)}#{identifier_quotation_char}"
  end

end
end
end
