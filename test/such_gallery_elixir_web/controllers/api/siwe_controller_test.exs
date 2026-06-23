defmodule SuchGalleryElixirWeb.Api.SiweControllerTest do
  use SuchGalleryElixirWeb.ConnCase, async: true

  alias SuchGalleryElixir.AccountsFixtures

  describe "POST /api/siwe/nonce" do
    test "returns a nonce and stores it in session" do
      conn = post(build_conn(), ~p"/api/siwe/nonce")

      assert %{"nonce" => nonce} = json_response(conn, 200)
      assert is_binary(nonce)
      assert String.length(nonce) > 0
    end
  end

  describe "DELETE /api/siwe/session" do
    test "clears the session" do
      user = AccountsFixtures.user_fixture()

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{user_id: user.id})
        |> delete(~p"/api/siwe/session")

      assert %{"ok" => true} = json_response(conn, 200)
    end
  end

  describe "GET /api/siwe/me" do
    test "returns current user when authenticated" do
      user = AccountsFixtures.user_fixture()

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{user_id: user.id})
        |> get(~p"/api/siwe/me")

      response = json_response(conn, 200)
      assert response["address"] == user.wallet_address
      assert response["display_name"] == user.display_name
    end

    test "returns 401 when not authenticated" do
      conn = get(build_conn(), ~p"/api/siwe/me")

      assert %{"error" => "Not authenticated"} = json_response(conn, 401)
    end
  end

  describe "POST /api/siwe/verify" do
    test "returns 400 when missing params" do
      conn = post(build_conn(), ~p"/api/siwe/verify", %{})

      assert %{"error" => "Missing message or signature"} = json_response(conn, 400)
    end

    test "returns 401 when signature is invalid" do
      conn =
        post(build_conn(), ~p"/api/siwe/verify", %{
          "message" => "such.gallery wants you to sign in",
          "signature" => "0xbadsig"
        })

      response = json_response(conn, 401)
      assert response["error"] =~ "Verification failed"
    end

    test "rejects requests without nonce in session" do
      # No nonce stored — should fail verification regardless
      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{siwe_nonce: nil})
        |> post(~p"/api/siwe/verify", %{
          "message" => "such.gallery wants you to sign in",
          "signature" => "0xbadsig"
        })

      assert %{"error" => error} = json_response(conn, 401)
      assert error =~ "Verification failed"
    end
  end
end
