require 'spec_helper'

describe "Static pages" do

  describe "Home page" do

    it "should have the content 'CreatorsShop'" do
      visit '/'
      expect(page).to have_content('CreatorsShop')
    end

    it "should have the title 'Home'" do
      visit '/'
      expect(page).to have_title("CreatorsShop | Home")
    end
  end
end