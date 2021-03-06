# frozen_string_literal: true

require "rails_helper"

describe API::V1::Tags, type: :request do
  let!(:admin) { create(:admin) }
  let!(:token) { create(:application_token, user: admin) }
  let!(:public_namespace) do
    create(:namespace,
           visibility: Namespace.visibilities[:visibility_public],
           team:       create(:team))
  end
  let!(:repository) { create(:repository, namespace: public_namespace) }

  before do
    @header = build_token_header(token)
  end

  context "GET /api/v1/tags" do
    it "returns an empty list" do
      get "/api/v1/tags", params: nil, headers: @header

      repositories = JSON.parse(response.body)
      expect(response).to have_http_status(:success)
      expect(repositories.length).to eq(0)
    end

    it "returns list of tags" do
      create(:tag, name: "taggg", repository: repository, digest: "1", author: admin)
      create(:tag, name: "another_tag", repository: repository, digest: "1", author: nil)
      create_list(:tag, 4, repository: repository, digest: "123123", author: admin)
      get "/api/v1/tags", params: nil, headers: @header

      tags = JSON.parse(response.body)
      expect(response).to have_http_status(:success)
      expect(tags.length).to eq(6)
    end
  end

  context "GET /api/v1/tags/:id" do
    it "returns a tag" do
      tag = create(:tag, name: "taggg", repository: repository, digest: "1", author: admin)
      get "/api/v1/tags/#{tag.id}", params: nil, headers: @header

      tag_parsed = JSON.parse(response.body)
      expect(response).to have_http_status(:success)
      expect(tag_parsed["id"]).to eq(tag.id)
      expect(tag_parsed["name"]).to eq(tag.name)
    end

    it "returns 404 if it doesn't exist" do
      get "/api/v1/tags/222", params: nil, headers: @header

      expect(response).to have_http_status(:not_found)
    end
  end

  context "DELETE /api/v1/tags/:id" do
    it "deletes tag" do
      APP_CONFIG["delete"]["enabled"] = true
      allow_any_instance_of(Portus::RegistryClient).to receive(:delete).and_return(true)

      tag = create(:tag, name: "taggg", repository: repository, digest: "1", author: admin)
      delete "/api/v1/tags/#{tag.id}", params: nil, headers: @header
      expect(response).to have_http_status(:no_content)
      expect { Tag.find(tag.id) }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "forbids deletion of tag (delete disabled)" do
      tag = create(:tag, name: "taggg", repository: repository, digest: "1", author: admin)
      delete "/api/v1/tags/#{tag.id}", params: nil, headers: @header
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 422 if unable to remove tag" do
      APP_CONFIG["delete"]["enabled"] = true
      allow_any_instance_of(Portus::RegistryClient).to receive(:delete) do
        raise ::Portus::RegistryClient::RegistryError, "I AM ERROR."
      end

      tag = create(:tag, name: "taggg", repository: repository, digest: "1", author: admin)
      delete "/api/v1/tags/#{tag.id}", params: nil, headers: @header
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns status 404" do
      delete "/api/v1/tags/999", params: nil, headers: @header
      expect(response).to have_http_status(:not_found)
    end
  end
end
