module TogoMapper
  extend self

  def d2rq_path=(path)
    @d2rq_path = path
  end

  def d2rq_path
    @d2rq_path
  end

  def dump_rdf
    "#{@d2rq_path}/dump-rdf"
  end

  def d2r_query
    "#{@d2rq_path}/d2r-query"
  end

end
