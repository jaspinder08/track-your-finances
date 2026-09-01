def test_check_email(client):
    response = client.get("/v1/user/check-email")
    assert response.status_code == 200
    assert response.json() == "jaspinderkaurjk08@gmail.com"

def test_login(client):
    response = client.get("/v1/user/login")
    assert response.status_code == 200
    assert response.json() == "jaspinderkaurjk08@gmail.com"
