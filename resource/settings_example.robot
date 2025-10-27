*** Settings ***
Resource    ../elements/main_elements.resource
Library    SeleniumLibrary
Library    Browser
Library    RequestsLibrary
Library    Collections
*** Variables ***
&{config}
...    browser=
...    url=
...    status=200