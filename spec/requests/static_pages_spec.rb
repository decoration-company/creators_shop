require 'rails_helper'

describe "Static pages" do

  describe "Home page" do

    it "should have the content 'CreatorsShop'" do
      visit '/'
      expect(page).to have_content('CreatorsShop')
    end

    it "should have the title 'Home'" do
      visit '/'
      expect(page).to have_title('Home - CreatorsShop')
    end
  end
end