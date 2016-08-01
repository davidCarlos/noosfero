module Api
  module V1
    class Profiles < Grape::API

      resource :profiles do

        get do
          profiles = select_filtered_collection_of(environment, 'profiles', params)
          profiles = profiles.visible
          profiles = profiles.by_location(params) # Must be the last. May return Exception obj.
          present profiles, :with => Entities::Profile, :current_person => current_person
        end

        post ':id/categories' do
          authenticate!
          profile = Profile.find(params[:id])
          category_ids = params[:profile].delete :category_ids
          profile = add_categories_to_asset(profile, category_ids)
          profile.save
          present profile, :with => Entities::Profile, :current_person => current_person
        end

        get ':id' do
          profiles = environment.profiles
          profiles = profiles.visible
          profile = profiles.find_by id: params[:id]

          if profile
            present profile, :with => Entities::Profile, :current_person => current_person
          else
            not_found!
          end
        end
        
        desc "Update profile information"
        post ':id' do
          authenticate!
          profile = environment.profiles.find_by(id: params[:id])
          return forbidden! unless profile.allow_edit?(current_person)
          profile.update_attributes!(params[:profile])
          present profile, :with => Entities::Profile, :current_person => current_person
        end

        delete ':id' do
          authenticate!
          profiles = environment.profiles
          profile = profiles.find_by id: params[:id]

          not_found! if profile.blank?

          if profile.allow_destroy?(current_person)
            profile.destroy
          else
            forbidden!
          end
        end
      end
    end
  end
end
