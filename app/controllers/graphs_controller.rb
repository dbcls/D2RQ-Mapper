class GraphsController < ApplicationController

  def d2rq
    redirect_to d2rq_mapping_url
  end

  def r2rml
    redirect_to r2rml_mapping_url
  end

  def turtle
    redirect_to turtle_url
  end

  def sparql
    redirect_to sparql_url
  end

end
