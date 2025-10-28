import os
import pytest
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from playwright.sync_api import sync_playwright
from dotenv import load_dotenv

load_dotenv()


@pytest.fixture
def selenium_driver(config):
    driver = webdriver.Chrome()
    driver.maximize_window()
    driver.get(config['url'])
    wait = WebDriverWait(driver, config['timeout'])
    dismiss_button = wait.until(
        EC.visibility_of_element_located((By.XPATH, "//span[contains(text(),'Dismiss')]"))
    )
    dismiss_button.click()
    yield driver
    driver.quit()


@pytest.fixture
def playwright_browser(config):
    browser_type = os.getenv('BROWSER', 'chromium')
    headless = os.getenv('HEADLESS', 'false').lower() == 'true'
    
    with sync_playwright() as p:
        browser_launcher = getattr(p, browser_type)
        browser = browser_launcher.launch(headless=headless)
        page = browser.new_page()
        page.goto(config['url'])
        page.click("//span[contains(text(),'Dismiss')]")
        yield page
        browser.close()
