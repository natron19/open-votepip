Rails.application.routes.draw do
  root "home#index"
  get  "/dashboard", to: "proposals#index", as: :dashboard

  resources :proposals do
    # index only redirects to the proposal: shared/_ai_error's "Try again" is a GET to the current path.
    resources :clarity_checks, only: %i[index create show], path: :checks
  end

  get  "/sign_up",  to: "registrations#new",    as: :sign_up
  post "/sign_up",  to: "registrations#create"

  get    "/sign_in",  to: "sessions#new",     as: :sign_in
  post   "/sign_in",  to: "sessions#create"
  delete "/sign_out", to: "sessions#destroy", as: :sign_out

  get   "/passwords/new",    to: "passwords#new",    as: :new_password
  post  "/passwords",        to: "passwords#create"
  get   "/passwords/edit",   to: "passwords#edit",   as: :edit_password
  patch "/passwords/:token", to: "passwords#update"

  namespace :admin do
    get  "/",                      to: "dashboard#show", as: :dashboard
    get  "/users",                 to: "users#index",    as: :users
    get  "/llm_requests",          to: "llm_requests#index", as: :llm_requests
    get  "/ai_templates",          to: "ai_templates#index", as: :ai_templates
    get  "/ai_templates/:id/edit", to: "ai_templates#edit",  as: :edit_ai_template
    patch "/ai_templates/:id",     to: "ai_templates#update", as: :ai_template
    post "/ai_templates/:id/test", to: "ai_templates#test",   as: :test_ai_template
  end

  get "/up/llm", to: "health#llm", as: :health_llm
  get "/up",     to: "rails/health#show", as: :rails_health_check
end
