require "rails_helper"

RSpec.describe "Home", type: :request do
  it "shows the pitch and the fictional example to visitors" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("2 proposals bundled", "That bikes may not be left in the ground-floor hallway.", "https://votepip.com")
    expect(response.body).to include("Try it free")
  end

  it "sends a signed-in member to their proposals" do
    sign_in_as(create(:user))
    get root_path
    expect(response.body).to include("Go to my proposals")
  end
end
