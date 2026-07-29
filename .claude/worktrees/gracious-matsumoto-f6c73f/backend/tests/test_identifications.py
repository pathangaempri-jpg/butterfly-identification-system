"""Tests for /api/v1/identifications/* endpoints."""


class TestTriggerIdentification:
    def test_identify_without_images_returns_400(self, client, auth, sample_observation):
        obs_id = sample_observation["id"]
        r = client.post(
            f"/api/v1/identifications/observations/{obs_id}/identify", headers=auth
        )
        assert r.status_code == 400
        assert "image" in r.get_json()["message"].lower()

    def test_identify_nonexistent_obs_returns_404(self, client, auth):
        r = client.post(
            "/api/v1/identifications/observations/fake-obs-id/identify", headers=auth
        )
        assert r.status_code == 404

    def test_identify_other_users_obs_returns_403(self, client, auth, make_observation):
        import uuid
        obs = make_observation()
        obs_id = obs["id"]

        # create a second user
        uid = uuid.uuid4().hex[:8]
        reg = client.post("/api/v1/auth/register", json={
            "email": f"ident_{uid}@test.invalid",
            "password": "Ident@Pass1",
            "full_name": "Ident User",
            "username": f"ident_{uid}",
        })
        assert reg.status_code == 201
        login = client.post("/api/v1/auth/login", json={
            "email": f"ident_{uid}@test.invalid",
            "password": "Ident@Pass1",
        })
        assert login.status_code == 200
        other_token = login.get_json()["data"]["access_token"]
        r = client.post(
            f"/api/v1/identifications/observations/{obs_id}/identify",
            headers={"Authorization": f"Bearer {other_token}"},
        )
        assert r.status_code == 403

    def test_identify_without_auth_returns_401(self, client, sample_observation):
        obs_id = sample_observation["id"]
        r = client.post(f"/api/v1/identifications/observations/{obs_id}/identify")
        assert r.status_code == 401


class TestGetIdentificationResult:
    def test_get_result_before_trigger_returns_404(self, client, auth, make_observation):
        obs = make_observation()
        obs_id = obs["id"]
        r = client.get(
            f"/api/v1/identifications/observations/{obs_id}/result", headers=auth
        )
        assert r.status_code == 404

    def test_get_result_nonexistent_obs_returns_404(self, client, auth):
        r = client.get(
            "/api/v1/identifications/observations/fake-obs-id/result", headers=auth
        )
        assert r.status_code == 404
