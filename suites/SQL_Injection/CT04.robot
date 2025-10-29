*** Settings ***
Library    SikuliLibrary
Resource    ../../shared/setup_teardown.robot
*** Test Cases ***
CT04 - Database Schema
    [Tags]    API
    Given eu realizo a busca por um item com o SQL introduzido
    When eu recebo a resposta da requisição
    Then eu verifico se a resposta trouxe o esquema inteiro do banco de dados nos parâmetros