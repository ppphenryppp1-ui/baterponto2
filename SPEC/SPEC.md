# SPEC - Sistema de Controle de Ponto (Entrada e Saída)

## 1. Visão Geral do Projeto

O **Sistema de Controle de Ponto** é uma solução web progressiva (PWA) de alta confiabilidade para registro e gestão da jornada de trabalho de funcionários. O sistema foi projetado para rodar prioritariamente em **tablets e desktops**, operando de forma online e com resiliência a falhas de conexão através de estratégias **Offline-First**.

### 1.1 Objetivo
Permitir que funcionários registrem seus batimentos diários de forma rápida, segura e biometrizada, emitindo comprovantes físicos (impressora) ou digitais (e-mail), tratando exceções de jornada (atrasos, faltas, saídas antecipadas) com fluxo de justificativa e auditoria para o RH.

---

## 2. Arquitetura e Stack Tecnológica

### 2.1 Especificação de Stack
* **Agente de Execução/Desenvolvimento:** Google Jules (agente de IA autônomo).
* **Hospedagem e Repositório:** GitHub.
* **Banco de Dados e Backend BaaS:** Supabase (PostgreSQL, Auth, Storage, Edge Functions), conectado exclusivamente via REST/Websockets pela SDK/API pública JavaScript.
* **Frontend:** HTML5, CSS3, JavaScript Vanilla (ES6+).
* **Gerenciamento de Pacotes / Dependências:** **Sem Node.js / NPM / Build Tools**. Todas as bibliotecas externas devem ser importadas via **CDN** (ex: jsDelivr, UNPKG, cdnjs).

### 2.2 Bibliotecas de Suporte (via CDN)
Para reduzir volume de código e evitar erros de implementação, devem ser utilizadas via `<script>`/`<link>`:
* **Supabase Client JS (v2):** `@supabase/supabase-js` para comunicação com banco e auth.
* **Lucide Icons:** `lucide` para renderização de ícones na interface (substituindo o uso de emojis).
* **Day.js:** `dayjs` com plugins de timezones para manipulação leve e precisa de datas e cálculos de saldo de horas.

---

## 3. Interface e Experiência do Usuário (UI / UX)

* **Dispositivos Alvo:** Exclusivo para telas de **Tablets (Landscape)** e **Desktops** (resolução mínima recomendada: 1024x768).
* **Estilo Visual:** Interface limpa, moderna, fundo predominantemente branco (`#FFFFFF` / `#F8FAFC`), alto contraste para leitura rápida.
* **Iconografia:** Uso obrigatório da biblioteca **Lucide Icons**. **Proibido o uso de emojis** nos componentes de interface do usuário.
* **APIs Nativas e Periféricos:**
  * **Biometria:** API `navigator.credentials` / **WebAuthn API** para autenticação biométrica via leitor/dispositivo.
  * **Cartão de Proximidade/RFID:** Leitura via captura transparente de eventos de teclado (dispositivo HID).
  * **Impressão:** Utilização do comando nativo `window.print()` estilizado com CSS `@media print` para cupom térmico.
  * **Rede:** API `navigator.onLine` e eventos `online`/`offline` para monitoramento de conexão.

---

## 4. Requisitos Funcionais e Regras de Negócio

### 4.1 Marcação de Jornada
O sistema deve suportar até 4 registros/batimentos padrão por dia para cada colaborador:
1. **Entrada no Expediente** 🚪
2. **Saída para Intervalo/Almoço** 🍽️
3. **Retorno do Intervalo/Almoço** ↩️
4. **Saída do Expediente** 🏁

#### Regras do Batimento:
* **Identificação Primária:** Leitura por **Impressão Digital (Biometria)** via WebAuthn.
* **Identificação de Contingência:** Leitura de **Cartão Magnético / RFID**.
  * **Regra de Exceção para Cartão:** O uso do cartão magnético ou a falha consecutiva na biometria (mais de 3 tentativas) **exige obrigatoriamente a senha e validação do Supervisor**.
  * **Alerta ao RH:** Qualquer registro efetuado via contingência/cartão deve gerar um **alerta imediato no painel do RH**.

### 4.2 Emissão de Comprovante (Ticket)
Aos concluir um registro com sucesso, o sistema deve emitir um comprovante contendo obrigatoriamente:
* **Dados do Empregador:** Razão Social, CNPJ, Endereço completo.
* **Dados do Trabalhador:** Nome completo, PIS, Cargo, Função.
* **Informações do Turno:** Horário padrão a ser cumprido.
* **Batimentos Diários:** Horário exato registrado pelo relógio no momento do batimento atual e anteriores do dia.
* **Hash de Autenticação:** Código hash de integridade gerado para o comprovante.

#### Meios de Entrega:
1. **Impresso:** Envio para a impressora térmica conectada.
2. **Digital:** Opção de envio automático do ticket por e-mail (disparado via Supabase Edge Function).

### 4.3 Gestão de Anomalias e Exceções de Jornada
* **Atrasos e Saídas Antecipadas:**
  * O sistema calcula a diferença entre o horário do registro e a grade horária do turno configurado (considerando a tolerância cadastrada).
  * Caso detectado atraso ou saída antecipada fora da tolerância, o sistema **exige a inserção de uma justificativa textual**.
  * O sistema registra a ocorrência, aplica a marcação de **desconto** e envia alerta visual para o gestor/RH.
* **Faltas e Ausências:**
  * Se ao término do expediente do turno o colaborador não apresentar nenhum batimento nem justificativa, o sistema agenda automaticamente o registro de **Falta**.
  * **Anexo de Atestado:** O sistema deve permitir o upload de comprovante/atestado médico em PDF ou Imagem (salvo no Supabase Storage) para abonar a falta ou justificá-la.

---

## 5. Arquitetura PWA e Suporte Offline (Offline-First)

### 5.1 Service Worker e Cache
* O Service Worker deve realizar o pré-cache de todos os arquivos estáticos (`index.html`, arquivos CSS, arquivos JS Vanilla, ícones) permitindo o carregamento da aplicação sem conectividade à internet.

### 5.2 Armazenamento Local (IndexedDB)
* Quando o dispositivo estiver offline (`navigator.onLine === false`), todos os registros de ponto realizados devem ser armazenados de forma criptografada/estruturada no **IndexedDB** local do navegador.
* Para evitar conflitos de ID durante a inserção descentralizada/offline, as chaves primárias dos registros devem utilizar **UUIDv4**.

### 5.3 Validação e Sincronização ao Reconectar
* **Detecção de Conexão:** Ao disparar o evento `online`, o PWA entra em modo de sincronização.
* **Fluxo de Validação:** Antes de persistir os dados no Supabase central, a rotina de sincronização executa um processo de **validação de integridade e duplicidade** no lote de batimentos offline acumulados:
  * Verifica se já existe um batimento idêntico (mesmo colaborador e mesmo timestamp).
  * Confirma a coerência temporal dos batimentos no lote.
* **Feedback de Erro e Contingência Visual:**
  * Se a conexão cair durante o uso, o PWA deve exibir imediatamente um **banner/notificação de aviso de perda de conexão**.
  * Se houver falha na impressora no momento da impressão, uma **notificação visual de falha no hardware/impressora** deve ser apresentada na tela com opção de reenviar ou encaminhar por e-mail.

---

## 6. Diretrizes de Banco de Dados (Supabase)

Toda a persistência central será realizada no **Supabase PostgreSQL**. As definições das tabelas, chaves estrangeiras, índices e políticas de segurança RLS estão especificadas no arquivo externo **`schema.sql`**.

### Resumo das Tabelas Core:
* `empresa`: Dados da Razão Social, CNPJ e Endereço.
* `turno`: Horários operacionais padrão e tolerâncias em minutos.
* `colaborador`: Cadastro de funcionários, vínculo de empresa/turno, dados trabalhistas (PIS, cargo, função) e hashes de biometria/cartão.
* `registro_ponto`: Batimentos realizados (Entrada/Intervalo/Retorno/Saída), método de auth, status de sincronização e aprovação de supervisor.
* `justificativa_ocorrencia`: Registro de justificativas para atrasos, saídas antecipadas, faltas e links de atestados anexados.
* `ticket_comprovante`: Histórico dos comprovantes gerados, hash de autenticação e status de impressão/e-mail.

---

## 7. Instruções Específicas para o Agente de IA (Google Jules)

Como agente de IA autônomo encarregado da implementação do projeto, você **DEVE** seguir rigorosamente as regras abaixo:

1. **Dúvidas e Incertezas:**
   * **NÃO CODIFIQUE** caso haja qualquer dúvida, ambiguidade ou indefinição nos requisitos. Solicite esclarecimentos ao usuário antes de implementar.
2. **Divisão de Tarefas Extensas:**
   * Sempre divida desenvolvimentos e tarefas complexas em etapas e sub-tarefas menores e testáveis.
3. **Registro Obrigatório no Backlog:**
   * Mantenha e atualize constantemente um arquivo **`backlog.md`** na raiz do repositório.
   * O arquivo `backlog.md` deve registrar todas as funcionalidades implementadas, corrigidas, refatoradas ou alteradas, categorizadas por versão/status (Pendente, Em Progresso, Concluído).
4. **Respeito Absoluto à Stack:**
   * Não adicione frameworks Node.js (React, Vue, Angular) nem bundlers (Webpack, Vite).
   * Utilize estritamente HTML5 semântico, CSS puro e JavaScript Vanilla com suporte PWA. Importe bibliotecas externas somente por CDN.
