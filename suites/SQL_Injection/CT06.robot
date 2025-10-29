*** Settings ***
Resource    ../../shared/setup_teardown.robot
*** Test Cases ***
CT06 - Credenciais dos Usuários
    [Tags]    API
    Given eu insiro um SQL malicioso no endpoint de busca para retornar as credenciais do usuário
    When eu insiro removendo outros dados e adicionando algo incomum no início da consulta
    Then eu verifico se a resposta contém as credenciais