Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  
  get '/ajax/new_property_bridge_form' => 'triples_maps#new_property_bridge_form'
  get '/ajax/del_property_bridge_form' => 'triples_maps#del_property_bridge_form'
  get '/ajax/new_predicate_form' => 'triples_maps#new_predicate_form'

  get '/ajax/er/server_load/:id' => 'er#server_load'
  get '/ajax/er/save_xml_dialog/:id' => 'er#save_xml_dialog'
  get '/ajax/er/subject_map_dialog/:id' => 'er#subject_map_dialog'
  get '/ajax/er/predicate_object_map_dialog/:id(/:mode)' => 'er#predicate_object_map_dialog'
  get '/ajax/er/table_join_dialog/:id/:target' => 'er#table_join_dialog'

  # Menu
  resources :menu

  # Mappings
  resources :mappings do
    member do
      get :namespaces
      get :tables
    end
  end
  

  # Set relational databases, basic configuration
  resources :works do
    member do
      post :er_data
    end
  end

  # ER-diagram
  resources :er do
    resources :class_maps, shallow: true do
      member do
        get  :enable
        post :toggle_enable
      end
    end
      
    resources :property_bridges, shallow: true do
      member do
        get  :enable
        post :toggle_enable
      end
    end
    
    member do
      get   :namespace
      get   :table_positions
      post  :upload_ontology
      patch :table_positions
    end
  end

  # Mapping
  resource :mapping do
    member do
      get :table
      get :configure
      get :namespace
    end
  end

  # Edit mapping
  resources :subject_maps do
    member do
      get   :records
    end
  end

  resources :triples_maps

  resources :table_joins do
    member do
      patch :subject_map
      patch :predicate_object_map
    end
  end
  
  resources :blank_nodes

  resources :namespaces, only: [ 'index', 'show', 'update' ]
  resource :namespace, only: [] do
    member do
      get :add_form
    end
  end

  resource :graph do
    member do
      get :d2rq
      get :r2rml
      get :turtle
      get :sparql
    end
  end

  resources :d2rq_mapping do
    member do
      get :download
      get :by_table
      get :by_column
      get :by_table_join
    end
  end

  resources :r2rml_mapping do
    member do
      get :download
    end
  end

  resources :turtle do
    member do
      get :download
      get :by_table
      get :by_column
      get :by_table_join
      get :preview
      get :generate
      get :generation_status
      get :refresh_button_area
    end
  end

  resources :sparql do
    member do
      post :search
    end
  end

  # Devise
  resources :password_resets
  devise_for :users,
             path_names: { sign_in: "login", sign_out: "logout" },
             controllers: { omniauth_callbacks: "omniauth_callbacks" }
  
  root 'index#welcome'
end
