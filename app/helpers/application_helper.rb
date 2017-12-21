module ApplicationHelper

  def dbadapter2jdbcdriver(adapter)
    case adapter
    when "mysql2"
      "com.mysql.jdbc.Driver"
    when "postgresql"
      "org.postgresql.Driver"
    else
      ""
    end
  end

  def jdbc_dsn(db_connection)
    case db_connection.adapter
    when "mysql2"
      host = db_connection.host == 'localhost' ? '127.0.0.1' : db_connection.host
      port = db_connection.port == 3306 ? '' : ":#{db_connection.port}"
      "jdbc:mysql://#{host}#{port}/#{db_connection.database}"
    when "postgresql"
      "jdbc:postgresql://#{db_connection.host}/#{db_connection.database}"
    else
      ""
    end
  end

  def existing_mapping_item_text(work)
    %Q|<span>#{work.name}</span><time datetime="#{work.updated_at.iso8601}">#{work.updated_at.strftime("%Y/%m/%d %H:%M")}</time>|
  end
  
end
