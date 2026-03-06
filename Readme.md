# SBDD - Security-Based Development and Deployment

Projeto de testes de segurança automatizados usando Robot Framework e OWASP Juice Shop.

## 📋 Pré-requisitos

- Windows 10/11
- PowerShell 5.1 ou superior
- Docker Desktop (será instalado automaticamente se necessário)
- Conexão com a internet

## 🚀 Início Rápido

### 1. Configurar Política de Execução do PowerShell

**IMPORTANTE**: O script `setup.ps1` **SEMPRE** verifica e configura a política de execução automaticamente. Você pode executá-lo diretamente:

```powershell
.\scripts\setup.ps1 -Command setup-robot
```

Se encontrar problemas, configure manualmente (aplica apenas ao processo atual - seguro):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

Depois execute o script novamente.

### 2. Instalar Robot Framework

```powershell
.\scripts\setup.ps1 -Command setup-robot
```

Este comando irá:
- ✅ Verificar a política de execução do PowerShell
- ✅ Verificar/instalar Python 3.12
- ✅ Instalar Robot Framework e bibliotecas
- ✅ Configurar ChromeDriver compatível com seu Chrome

### 3. Configurar Ambiente Completo

```powershell
.\scripts\setup.ps1 -Command setup
```

Este comando irá:
- ✅ Verificar Docker
- ✅ Verificar Python 3.12
- ✅ Instalar dependências do requirements.txt
- ✅ Configurar ChromeDriver
- ✅ Iniciar OWASP Juice Shop

## 📚 Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `setup` | Configuração completa do ambiente (padrão) |
| `setup-robot` | Configurar apenas Robot Framework |
| `install-docker` | Instalar Docker Desktop |
| `enable-virtualization` | Habilitar virtualização no Windows |
| `run-tests` | Executar testes pytest |
| `help` | Exibir ajuda |

## 🔧 Opções

| Opção | Descrição |
|-------|-----------|
| `-Full` | Setup completo (virtualização + docker + dependências) |
| `-Marker <marker>` | Executar testes com marcador específico |
| `-Verbose` | Saída detalhada dos testes |

## 💡 Exemplos de Uso

### Setup completo do ambiente
```powershell
.\scripts\setup.ps1
```

### Setup com todas as features
```powershell
.\scripts\setup.ps1 -Command setup -Full
```

### Executar testes específicos
```powershell
.\scripts\setup.ps1 -Command run-tests -Marker ui
.\scripts\setup.ps1 -Command run-tests -Marker api -Verbose
```

### Instalar Docker
```powershell
.\scripts\setup.ps1 -Command install-docker
```

## 🔍 Verificação da Política de Execução

O script **SEMPRE** executa as seguintes verificações:

1. **No início do script**: Verifica a política antes de qualquer operação
2. **Antes de instalações**: Revalida antes de instalar Python, Docker, etc.
3. **Feedback visual**: Mostra claramente o status da política

### Comando Usado
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

**Por que este comando?**
- ✅ **Seguro**: Afeta apenas o processo atual do PowerShell
- ✅ **Temporário**: A política volta ao normal quando você fecha a janela
- ✅ **Sem impacto permanente**: Não modifica configurações do sistema
- ✅ **Não requer administrador**: Funciona sem privilégios elevados

### Exemplo de Saída
```
========================================
Checking PowerShell Execution Policy
========================================

Current Execution Policy: Restricted
Execution policy is TOO restrictive!
Setting execution policy to Bypass for this process...

✓ Execution policy set to Bypass for current process successfully!
  (This change applies only to this PowerShell session)
```

## 🛠️ Recursos Automáticos

### ChromeDriver
- **Detecção automática** da versão do Chrome instalada
- **Verificação de compatibilidade** do ChromeDriver existente
- **Instalação/atualização automática** se necessário
- Pergunta antes de reinstalar se já estiver compatível

### Python 3.12
- **Detecção de versões incompatíveis**
- **Oferece desinstalação** de outras versões
- **Instalação automática** do Python 3.12.7
- Configuração automática do PATH

## 📁 Estrutura do Projeto

```
SBDD/
├── scripts/
│   └── setup.ps1          # Script principal de configuração
├── elements/              # Elementos da interface
├── steps/                 # Steps dos testes
├── suites/                # Suites de testes
│   └── SQL_Injection/     # Testes de SQL Injection
├── resource/              # Recursos compartilhados
├── shared/                # Setup e teardown compartilhados
├── docker-compose.yml     # Configuração do Docker (Juice Shop)
├── requirements.txt       # Dependências Python
├── .gitignore            # Arquivos ignorados pelo Git
└── Readme.md             # Este arquivo
```

## 🐳 Docker / OWASP Juice Shop

O projeto usa Docker para executar o [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/), uma aplicação web vulnerável para testes de segurança.

### Configuração Automática

O script `setup.ps1` configura automaticamente:
- Verifica se o Docker está instalado
- Inicia o Docker Desktop se necessário
- Faz download da imagem do Juice Shop
- Inicia o container
- Aguarda até que a aplicação esteja pronta

### Comandos Docker Úteis

**Iniciar Juice Shop:**
```powershell
docker-compose up -d
```

**Parar Juice Shop:**
```powershell
docker-compose down
```

**Ver logs em tempo real:**
```powershell
docker-compose logs -f
```

**Reiniciar container:**
```powershell
docker-compose restart
```

**Ver status dos containers:**
```powershell
docker ps
```

### Acessar o Juice Shop

Após iniciar, acesse: **http://localhost:3000**

## 🐛 Solução de Problemas

### Erro: "Cannot be loaded because running scripts is disabled"

**Solução 1**: Execute o setup.ps1, ele corrigirá automaticamente

**Solução 2**: Configure manualmente (temporário, apenas para o processo atual)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

Depois execute o script:
```powershell
.\scripts\setup.ps1
```

### Erro: "Python not found"

Execute:
```powershell
.\scripts\setup.ps1 -Command setup-robot
```
O script detectará e oferecerá instalar o Python 3.12.

### ChromeDriver incompatível

Execute novamente o setup do Robot Framework:
```powershell
.\scripts\setup.ps1 -Command setup-robot
```
O script detectará a incompatibilidade e instalará a versão correta.

### Docker/Juice Shop não inicia

**Verificar status do container:**
```powershell
docker ps -a
```

**Ver logs do container:**
```powershell
docker-compose logs -f
```

**Reiniciar container:**
```powershell
docker-compose down
docker-compose up -d
```

**Verificar se a porta 3000 está em uso:**
```powershell
netstat -ano | findstr :3000
```

Se a porta estiver em uso, finalize o processo ou altere a porta no `docker-compose.yml`.

### Browser Library não inicializado

**Erro:** `Browser library is not initialized`

**Solução:**
```powershell
python -m Browser.entry init
```

Ou execute novamente o setup:
```powershell
.\scripts\setup.ps1 -Command setup-robot
```

**Verificar instalação:**
```powershell
python -m Browser.entry version
```

## 📝 Dependências

As dependências estão definidas em `requirements.txt`:

- Robot Framework 6.0+
- SeleniumLibrary
- Browser Library (Playwright) - **requer inicialização com `rfbrowser init`**
- RequestsLibrary
- JSONLibrary
- SikuliLibrary

### Inicialização do Browser Library

O Browser Library usa Playwright e requer a instalação dos binários dos navegadores. O script `setup.ps1` faz isso automaticamente, mas você também pode executar manualmente:

```powershell
python -m Browser.entry init
```

Ou:

```powershell
rfbrowser init
```

Este comando baixa os binários dos navegadores (Chromium, Firefox, WebKit) - aproximadamente 400MB.

## 🤝 Contribuindo

1. Faça fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT.

## 👥 Autores

ASTRID-RESEARCH

## 🔗 Links Úteis

- [Robot Framework](https://robotframework.org/)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
- [SeleniumLibrary](https://github.com/robotframework/SeleniumLibrary)
- [Browser Library](https://github.com/MarketSquare/robotframework-browser)
