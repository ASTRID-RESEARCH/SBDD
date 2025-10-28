import os
import pytest
from dotenv import load_dotenv

load_dotenv()


@pytest.fixture
def config():
    return {
        'url': os.getenv('JUICE_SHOP_URL', 'http://localhost:3000'),
        'status': 200,
        'timeout': int(os.getenv('TIMEOUT', '30'))
    }


@pytest.fixture
def api_headers():
    return {'Content-Type': 'application/json'}
