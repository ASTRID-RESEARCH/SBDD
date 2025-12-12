import sys
from pathlib import Path

src_path = Path(__file__).parent / 'src'
sys.path.insert(0, str(src_path))

# Import fixtures only when running with pytest
try:
    from src.fixtures.config_fixtures import config, api_headers
    from src.fixtures.browser_fixtures import selenium_driver, playwright_browser
    
    __all__ = ['config', 'api_headers', 'selenium_driver', 'playwright_browser']
except ImportError:
    pass
