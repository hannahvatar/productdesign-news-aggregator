Rails.application.routes.draw do
  # Remove or comment out the devise_for line
  # devise_for :users

  resources :articles, only: [:index, :show] do
    collection do
      post :scrape
    end
  end

  root to: "articles#index"

  # Keep other routes as needed
  get "up" => "rails/health#show", as: :rails_health_check
end
