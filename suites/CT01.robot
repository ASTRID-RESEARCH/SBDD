*** Settings ***
Resource    ../shared/setup_teardown.robot
Test Setup    Acesso ao site
Test Teardown    Fechar o navegador
*** Test Cases ***
CT01 - Login Admin
    [Tags]    UI
    Given eu clico em conta
    And eu clico em login
    When eu preencho o campo de email com SQLi malicioso
    And eu preencho o campo de senha com qualquer valor
    When eu pressiono o botão de login
    And eu clico em conta
    Then eu verifico se recebi acesso de administrador