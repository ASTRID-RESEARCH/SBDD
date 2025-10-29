*** Settings ***
Resource    ../../shared/setup_teardown.robot
Test Setup    Acesso ao site
Test Teardown    Fechar o navegador
*** Test Cases ***
CT03 - Login Bender
    [Tags]    UI
    Given eu clico em conta
    And eu clico em login
    When eu preencho o campo de email com os dados maliciosos para a conta do Bender
    And eu preencho o campo de senha com qualquer valor
    When eu pressiono o botão de login
    And eu clico em conta
    Then eu verifico se tenho acesso à conta do Bender