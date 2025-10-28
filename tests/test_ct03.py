import pytest
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from src.locators import HomeLocators, LoginLocators


@pytest.mark.ui
def test_ct03_login_bender(selenium_driver, config):
    driver = selenium_driver
    wait = WebDriverWait(driver, config['timeout'])
    
    account_button = wait.until(EC.visibility_of_element_located((By.XPATH, HomeLocators.BUTTON_ACCOUNT)))
    account_button.click()
    
    login_button = wait.until(EC.visibility_of_element_located((By.XPATH, HomeLocators.BUTTON_LOGIN)))
    login_button.click()
    
    email_field = wait.until(EC.visibility_of_element_located((By.XPATH, LoginLocators.FIELD_EMAIL)))
    email_field.send_keys("bender@juice-sh.op' --")
    
    password_field = wait.until(EC.visibility_of_element_located((By.XPATH, LoginLocators.FIELD_PASSWORD)))
    password_field.send_keys("123")
    
    login_submit = wait.until(EC.visibility_of_element_located((By.XPATH, LoginLocators.BUTTON_LOGIN)))
    login_submit.click()
    
    account_button = wait.until(EC.visibility_of_element_located((By.XPATH, HomeLocators.BUTTON_ACCOUNT)))
    account_button.click()
    
    wait.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), HomeLocators.ACCOUNT_BENDER))
