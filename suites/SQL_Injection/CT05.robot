*** Settings ***
Resource    ../../shared/setup_teardown.robot
*** Test Cases ***
CT05 - Login com conta inexistente
    [Tags]    UI    API
    Given eu realizo a busca por um item com o SQL introduzido
    And eu recebo a resposta da requisição
    When eu verifico se a resposta trouxe o esquema inteiro do banco de dados nos parâmetros
    And eu executo a consulta usando UNION para criar a conta de efêmera
    Then eu verifico a criação da conta
    When eu abro o site
    And eu clico em conta para fazer login
    And eu clico em conectar
    And eu preencho o campo com o email cadastrado via injeção SQL
    And eu preencho o campo com a senha cadastrada via injeção SQL
    And eu clico no botão de login
    And eu clico em conta para fazer login
    Then eu verifico se tenho acesso à conta efêmera
