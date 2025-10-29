*** Settings ***
Resource    ../steps/main_steps.resource
Resource    ../resource/settings.robot
Library    OperatingSystem

*** Keywords ***
Acesso ao site
    Given eu acesso o site OWASP Juice Shop
    Then eu clico em Dismiss
Fechar o navegador
    Close All Browsers