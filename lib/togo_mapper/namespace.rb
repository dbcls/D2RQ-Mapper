module TogoMapper
module Namespace

  def namespaces_by_namespace_settings(work_id)
    NamespaceSetting.where(work_id: work_id).map{ |nss|
      { prefix: nss.namespace.prefix, uri: nss.namespace.uri }
    }
  end


  def namespace_prefixes_by_namespace_settings(work_id)
    NamespaceSetting.where(work_id: work_id).map{ |nss| nss.namespace.prefix }
  end

end
end
