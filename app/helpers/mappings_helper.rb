require 'uri'
require 'togo_mapper/mapping'

module MappingsHelper
  include TogoMapper::Mapping

  def options_for_subject_type_selector(selected_value = 0)
    h = { "(Not use this table)" => 0 }

    ClassMapProperty.for_resource_identity.each do |cmap|
      h[cmap.label] = cmap.id
    end

    options_for_select(h, selected_value)
  end


  def options_for_subject_property_selector(selected_value = 0)
    h = {}
    ClassMapProperty.not_resource_identity.each do |cmap|
      h[cmap.label] = cmap.id
    end

    options_for_select(h, selected_value)
  end


  def options_for_property_bridge_subject_selector(work, selected_value = 0)
    h = {}
    work.class_maps.each do |class_map|
      h[class_map.map_name] = class_map.id
    end

    options_for_select(h, selected_value)
  end


  def options_for_property_bridge_predicate_type_selector(selected_value = 0)
    h = {}
    PropertyBridgeProperty.predicate_properties.each do |pb_prop|
      h[pb_prop.label] = pb_prop.id
    end

    options_for_select(h, selected_value)
  end


  def options_for_property_bridge_object_type_selector(selected_value = 0)
    h = {}
    PropertyBridgeProperty.object_properties.each do |pb_prop|
      h[pb_prop.label] = pb_prop.id
    end

    options_for_select(h, selected_value)
  end


  def options_for_property_property_selector(selected_value = 0)
    h = {}
    PropertyBridgeProperty.optional_properties.each do |pb_prop|
      h[pb_prop.label] = pb_prop.id
    end

    options_for_select(h, selected_value)
  end


  def options_for_property_object_value_selector(values, selected_value)
    h = {}
    values.each do |value|
      h[value] = value
    end

    options_for_select(h, selected_value)
  end


  def escape_double_quot(str)
    str.gsub('"', "\\\"")
  end


  def lt_str(html_escape = false)
    html_escape ? '&lt;' : '<'
  end


  def gt_str(html_escape = false)
    html_escape ? '&gt;' : '>'
  end


  def amp_str(html_escape = false)
    html_escape ? '&amp;' : '&'
  end

  
  def tables_sp_icon(class_map)
    # Subject
    htmls = ['<span class="icon-set bg-primary']
    if class_map.nil? || !class_map.enable
      htmls << ' disabled'
    end
    htmls << '">S</span>'

    # Predicate
    htmls << '<span class="icon-set'
    
    if class_map.nil? || PropertyBridge.where(class_map_id: class_map.id, enable: true).empty?
      htmls << ' disabled'
    end
    htmls << '">P</span>'

    htmls.join
  end


  def example_records_sp_icon(class_map, property_bridge)
    htmls = []

    subject_cmp_ids = ClassMapProperty.for_resource_identity.map(&:id)
    subject_cmp_ids << ClassMapProperty.bnode.id

    subject_cmps = ClassMapPropertySetting.where(
      class_map_id: class_map.id,
      class_map_property_id: subject_cmp_ids
    ).first
    if subject_cmps.value.include?("#{class_map.table_name}.#{property_bridge.column_name}")
      htmls << '<span class="icon-set bg-primary">S</span>'
    end

    if property_bridge.enable
      htmls << '<span class="icon-set">P</span>'
    end

    htmls.join
  end


  def absolute_uri(base_uri, v)
    return v if v.blank?

    if v[0 .. 3] == 'col_'
      rv = v[4 .. -1]
    else
      rv = v
    end
    
    begin
      uri = URI.parse(rv)
      if uri.scheme.nil?
        "#{base_uri}#{rv}"
      else
        rv
      end
    rescue
      rv
    end
  end


  def uri_for_disp(base_uri, namespace_prefixes, v)
    begin
      if v.blank?
        ""
      elsif /\A<.*>\z/ !~ v
        v
      else
        uri = v[1 .. -2]
        prefix = uri.split(':')[0]
        if namespace_prefixes.include?(prefix)
          uri
        else
          "<#{absolute_uri(base_uri, uri)}>"
        end
      end
    rescue
      v
    end
  end


  def object_value(base_uri, prop_brige_prop_setting)
    if prop_brige_prop_setting && prop_brige_prop_setting.uri_pattern?
      absolute_uri(base_uri, prop_brige_prop_setting.value)
    else
      prop_brige_prop_setting ? prop_brige_prop_setting.value : ""
    end
  end


  def object_value_for_disp(base_uri, namespace_prefixes, prop_brige_prop_setting)
    if prop_brige_prop_setting && prop_brige_prop_setting.uri_pattern?
      uri_for_disp(base_uri, namespace_prefixes, prop_brige_prop_setting.value)
    else
      object_value(base_uri, prop_brige_prop_setting)
    end
  end


  def ontology_uri_for_disp(work_id, prefix, vocab)
    namespace = Namespace.where(prefix: prefix).first
    if namespace
      if namespace.is_default
        "#{prefix}:#{vocab}"
      else
        "#{prefix}#{vocab}"
      end
=begin
      namespace_setting = NamespaceSetting.where(work_id: work_id, namespace_id: namespace.id).first
      if namespace_setting
        "#{prefix}:#{vocab}"
      else
        "#{prefix}#{vocab}"
      end
=end
    else
      "#{prefix}#{vocab}"
    end
  end


  def ontology_tree_html(iri, sub_iri, span_class)
    s = []
    iri.keys.sort.each do |prefix|
      s << "<li><span>#{prefix}</span><ul>"
      iri[prefix].each do |name|
        s << %Q|<li>#{ontology_tree_li_child(ontology_uri_for_disp(@work.id, prefix, name), sub_iri, span_class)}</li>|
      end
      s << "</ul></li>"
    end

    s.join("\n")
  end


  def ontology_tree_li_child(iri, sub_iri, span_class)
    if sub_iri.key?(iri)
      s = ["<span>#{iri}</span><ul>"]
      sub_iri[iri].each do |ns|
        s << %Q|<li>#{ontology_tree_li_child(ns, sub_iri, span_class)}</li>|
      end
      s << "</ul>"
    else
      s = [%Q|<span><span class="#{span_class}">#{iri}</span></span>|]
    end

    s.join("\n")
  end
  
end
